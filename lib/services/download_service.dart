import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'cache_manager_service.dart';

/// Represents a single chapter download job and tracks its runtime state.
///
/// Instances are created by [DownloadService.downloadChapter] and stored in
/// [DownloadService.queueNotifier] so the UI can reactively reflect changes.
class DownloadTask {
  /// MangaDex chapter UUID — used as the unique key for this task.
  final String chapterId;

  /// MangaDex manga UUID — used to organise files into per-manga folders.
  final String mangaId;

  /// Human-readable manga title shown in the download queue UI.
  final String mangaTitle;

  /// Chapter number string (e.g. `"12"`) used for display and DB storage.
  final String chapterNum;

  /// Ordered list of full image URLs for every page in this chapter.
  final List<String> imageUrls;

  /// The URL for the manga cover image.
  final String? coverUrl;

  /// Comma-separated genre tags for the parent manga (e.g. `"Action, Drama"`).
  /// Defaults to `"Manga"` when genre data is unavailable.
  final String genre;

  /// Download completion fraction in the range `[0.0, 1.0]`.
  double progress;

  /// Zero-based index of the page to start (or resume) downloading from.
  /// Advances when a task is paused mid-chapter so work is not duplicated.
  int resumeFromPage;

  /// Current lifecycle state of the task.
  ///
  /// Valid values: `'queued'`, `'downloading'`, `'paused'`, `'done'`, `'error'`.
  String status;

  /// Human-readable error description populated when [status] is `'error'`.
  String errorMessage;

  DownloadTask({
    required this.chapterId,
    required this.mangaId,
    required this.mangaTitle,
    required this.chapterNum,
    required this.imageUrls,
    this.coverUrl,
    this.genre = 'Manga',
    this.progress = 0.0,
    this.resumeFromPage = 0,
    this.status = 'queued',
    this.errorMessage = '',
  });
}

/// A singleton service that manages a sequential chapter download queue.
///
/// ### Architecture
/// - Downloads are executed one at a time via [_processQueue], which loops
///   over all `'queued'` tasks until none remain.
/// - The queue is exposed as a [ValueNotifier] so the UI rebuilds reactively
///   whenever a task is added, updated, or removed.
/// - Pause/resume is implemented via the [_pauseRequested] flag, which is
///   checked between individual page downloads rather than mid-request, to
///   avoid partial file writes.
///
/// ### File layout
/// ```
/// <root>/downloads/<mangaId>/<chapterId>/001.jpg
///                                        002.jpg
///                                        ...
/// ```
/// `<root>` is either the user-configured path from [SharedPreferences] or
/// the app's documents directory.
class DownloadService {
  /// The single shared instance returned by the factory constructor.
  static final DownloadService _instance = DownloadService._internal();

  /// Returns the shared [DownloadService] instance.
  factory DownloadService() => _instance;

  /// Private constructor — prevents external instantiation.
  DownloadService._internal();

  String _sanitizeFolderName(String input) {
    final sanitized = input
        .replaceAll(RegExp(r'[<>:"\/\\|?*]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        .trim();
    return sanitized.isEmpty ? 'manga' : sanitized;
  }

  // ── HTTP Client ───────────────────────────────────────────────────────────

  /// Dio client pre-configured with timeouts and headers required by MangaDex.
  ///
  /// - `connectTimeout` — max time to establish a TCP connection.
  /// - `receiveTimeout` — max time between bytes during a download; set higher
  ///   than connect timeout to handle slow CDN responses.
  /// - `Referer` header — some MangaDex CDN nodes require this to serve images.
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'YugenManga/1.0.0',
      'Referer': 'https://mangadex.org',
    },
  ));

  // ── Dependencies & State ──────────────────────────────────────────────────

  /// Database helper used to persist completed downloads.
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Observable list of all current download tasks.
  ///
  /// The UI (e.g. `DownloadQueueScreen`) should listen to this notifier and
  /// rebuild whenever it changes. Tasks are removed from the list ~2 seconds
  /// after reaching `'done'` or immediately after `'error'` cleanup.
  final ValueNotifier<List<DownloadTask>> queueNotifier =
      ValueNotifier<List<DownloadTask>>([]);

  /// Whether [_processQueue] is currently running its loop.
  /// Guards against starting a second concurrent loop.
  bool _isProcessing = false;

  /// The [DownloadTask.chapterId] of the task currently being downloaded,
  /// or `null` when the queue is idle.
  String? _activeChapterId;

  /// When `true`, the active download loop will pause after the current page
  /// completes, before starting the next one.
  bool _pauseRequested = false;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Enqueues a chapter for download and starts processing if idle.
  ///
  /// If a task for [chapterId] already exists in the queue (in any state),
  /// this call is a no-op to prevent duplicates.
  ///
  /// [onProgress] receives values in `[0.0, 1.0]` as pages are saved, but
  /// only for the chapter whose [chapterId] matches the one passed here.
  /// Progress updates for other tasks in the queue are routed internally.
  Future<bool> downloadChapter({
    required String mangaId,
    required String mangaTitle,
    required String chapterId,
    required String chapterNum,
    required List<String> imageUrls,
    String? coverUrl,
    required Function(double) onProgress,
    String genre = 'Manga',
  }) async {
    // Prevent duplicate entries for the same chapter.
    final exists = queueNotifier.value.any((t) => t.chapterId == chapterId);
    if (exists) return false;

    final task = DownloadTask(
      chapterId: chapterId,
      mangaId: mangaId,
      mangaTitle: mangaTitle,
      chapterNum: chapterNum,
      imageUrls: imageUrls,
      coverUrl: coverUrl,
      genre: genre,
    );

    // Append to the queue using a new list reference so ValueNotifier fires.
    queueNotifier.value = [...queueNotifier.value, task];
    debugPrint(
        "📥 Queued: $mangaTitle Ch.$chapterNum (${imageUrls.length} pages)");

    // Only start a new processing loop if one isn't already running.
    if (!_isProcessing) {
      _processQueue(onProgressForCurrent: onProgress, currentId: chapterId);
    }
    return true;
  }

  /// Pauses the task identified by [chapterId].
  ///
  /// - If the task is **active** (currently downloading), sets
  ///   [_pauseRequested] so the loop stops after the current page finishes.
  /// - If the task is **queued but not yet active**, its status is set to
  ///   `'paused'` directly, removing it from the pending work list.
  void pauseTask(String chapterId) {
    if (_activeChapterId == chapterId) {
      _pauseRequested = true;
      debugPrint("⏸ Pause requested for $chapterId");
    } else {
      _updateTask(chapterId, status: 'paused');
    }
  }

  /// Resumes a previously paused task by setting its status back to `'queued'`
  /// and restarting the processing loop if it has stopped.
  ///
  /// The task will resume from [DownloadTask.resumeFromPage], skipping pages
  /// that were already downloaded.
  void resumeTask(String chapterId) {
    _updateTask(chapterId, status: 'queued');
    debugPrint("▶️ Resumed: $chapterId");
    if (!_isProcessing) {
      _processQueue(
        onProgressForCurrent: (_) {},
        currentId: chapterId,
      );
    }
  }

  // ── Queue Processing ──────────────────────────────────────────────────────

  /// Core download loop — processes all `'queued'` tasks sequentially.
  ///
  /// [onProgressForCurrent] and [currentId] route per-page progress callbacks
  /// back to the caller that originally enqueued the chapter. Tasks processed
  /// later in the same loop run silently (progress is still tracked in state).
  ///
  /// The loop exits when no `'queued'` tasks remain, setting [_isProcessing]
  /// back to `false` so the next [downloadChapter] or [resumeTask] call can
  /// restart it.
  Future<void> _processQueue({
    required Function(double) onProgressForCurrent,
    required String currentId,
  }) async {
    _isProcessing = true;

    while (true) {
      final pending =
          queueNotifier.value.where((t) => t.status == 'queued').toList();
      if (pending.isEmpty) break;

      final task = pending.first;
      _activeChapterId = task.chapterId;
      _pauseRequested = false;

      try {
        _updateTask(task.chapterId, status: 'downloading');
        debugPrint(
            "⬇️ Downloading: ${task.mangaTitle} Ch.${task.chapterNum} from page ${task.resumeFromPage + 1}");

        // Resolve the save directory: prefer the user-configured path from
        // settings, falling back to the app's documents directory.
        final prefs = await SharedPreferences.getInstance();
        final customPath = prefs.getString('downloadPath');

        String folderPath;
        final safeTitle = _sanitizeFolderName(task.mangaTitle);
        if (customPath != null && customPath != 'Default (Internal)') {
          // Use custom path for backward compatibility, but still organize by manga title
          folderPath = p.join(customPath, safeTitle, task.chapterId);
          print('DownloadService: Using custom path: $folderPath');
        } else {
          // Use the hidden cache directory from CacheManagerService
          final cacheDir = await CacheManagerService.instance.getChapterCacheDirectory(
            task.mangaTitle,
            task.chapterId,
          );
          folderPath = cacheDir.path;
          print('DownloadService: Using cache manager path: $folderPath');
        }

        // Ensure the target directory exists before writing any files.
        final dir = Directory(folderPath);
        if (!await dir.exists()) await dir.create(recursive: true);
        
        // Download and save cover image if it doesn't exist yet
        String? coverPath;
        if (task.coverUrl != null) {
          try {
            final mangaDir = dir.parent; // Save cover in the manga root folder
            final cp = '${mangaDir.path}/cover.jpg';
            if (!File(cp).existsSync()) {
              await _dio.download(task.coverUrl!, cp);
            }
            coverPath = cp;
          } catch (e) {
            debugPrint("Failed to download cover: $e");
          }
        }

        bool wasPaused = false;

        // Iterate pages starting from resumeFromPage to support mid-chapter resume.
        for (int i = task.resumeFromPage; i < task.imageUrls.length; i++) {
          // Check the pause flag before each page so we stop cleanly between
          // requests rather than abandoning a half-written file.
          if (_pauseRequested) {
            _updateTask(task.chapterId, status: 'paused', resumeFromPage: i);
            debugPrint("⏸ Paused at page ${i + 1}");
            wasPaused = true;
            break;
          }

          // Ghost Mode: Zero-pad filename but OMIT extensions to remain
          // invisible to standard gallery scanners.
          final savePath = p.join(folderPath, (i + 1).toString().padLeft(3, '0'));

          // Skip pages that were already saved in a previous (interrupted) run.
          if (!File(savePath).existsSync()) {
            await _dio.download(task.imageUrls[i], savePath);
          }

          final progress = (i + 1) / task.imageUrls.length;
          _updateTask(task.chapterId, progress: progress);
          // Only invoke the external progress callback for the originally requested chapter.
          if (task.chapterId == currentId) onProgressForCurrent(progress);
        }

        // If paused mid-chapter, skip DB insertion and move to the next task.
        if (wasPaused) {
          _activeChapterId = null;
          _pauseRequested = false;
          continue;
        }

        // All pages downloaded — persist the record and mark done.
        await _dbHelper.insertDownload({
          'id': task.chapterId,
          'mangaId': task.mangaId,
          'mangaTitle': task.mangaTitle,
          'chapterNum': task.chapterNum,
          'localPath': folderPath,
          'coverPath': coverPath,
          'genre': task.genre,
        });

        _updateTask(task.chapterId, status: 'done', progress: 1.0);
        debugPrint("✅ Done: ${task.mangaTitle} Ch.${task.chapterNum}");

        // Brief delay so the "done" state is visible in the UI before removal.
        await Future.delayed(const Duration(seconds: 2));
        queueNotifier.value = queueNotifier.value
            .where((t) => t.chapterId != task.chapterId)
            .toList();
      } on DioException catch (e) {
        // Network-level errors are translated to readable messages.
        final msg = _dioErrorMessage(e);
        debugPrint("❌ DioError: $msg");
        _updateTask(task.chapterId, status: 'error', errorMessage: msg);
      } catch (e) {
        // Catch-all for unexpected errors (e.g. file system permission issues).
        debugPrint("❌ Error: $e");
        _updateTask(task.chapterId,
            status: 'error', errorMessage: e.toString());
      }

      _activeChapterId = null;
    }

    _isProcessing = false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Converts a [DioException] into a concise, user-readable error string.
  ///
  /// Covers the most common failure modes; all other cases fall back to
  /// Dio's own message (or `'Unknown error'` if that is also absent).
  String _dioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out.';
      case DioExceptionType.receiveTimeout:
        return 'Server too slow.';
      case DioExceptionType.badResponse:
        return 'Server error: ${e.response?.statusCode}';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      default:
        return e.message ?? 'Unknown error';
    }
  }

  /// Mutates the fields of the task identified by [chapterId] inside
  /// [queueNotifier], then emits a new list reference to trigger listeners.
  ///
  /// Only non-null arguments are applied, so callers can update a subset of
  /// fields without needing to supply the others.
  void _updateTask(String chapterId,
      {double? progress,
      String? status,
      String? errorMessage,
      int? resumeFromPage}) {
    queueNotifier.value = queueNotifier.value.map((t) {
      if (t.chapterId == chapterId) {
        if (progress != null) t.progress = progress;
        if (status != null) t.status = status;
        if (errorMessage != null) t.errorMessage = errorMessage;
        if (resumeFromPage != null) t.resumeFromPage = resumeFromPage;
      }
      return t;
    }).toList();
  }

  /// Cancels the task identified by [chapterId], removing it from the queue
  /// immediately regardless of its current status.
  ///
  /// If the task is actively downloading, [_pauseRequested] is set so the
  /// page loop stops cleanly before the task disappears from the list.
  /// Note: any files already written to disk are **not** deleted.
  void cancelTask(String chapterId) {
    if (_activeChapterId == chapterId) _pauseRequested = true;
    queueNotifier.value =
        queueNotifier.value.where((t) => t.chapterId != chapterId).toList();
  }

  /// Removes all tasks that are not actively downloading (`status != 'downloading'`).
  ///
  /// The active task is intentionally preserved so an in-progress download
  /// is not interrupted. Callers can use [cancelTask] to stop it explicitly.
  void clearQueue() {
    queueNotifier.value =
        queueNotifier.value.where((t) => t.status == 'downloading').toList();
  }
}
