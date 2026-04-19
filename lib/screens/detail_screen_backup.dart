import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import 'reader_screen.dart';
import '../services/download_service.dart';
import '../services/database_helper.dart';
import 'download_queue_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DetailScreen extends StatefulWidget {
  final Manga manga;
  const DetailScreen({super.key, required this.manga});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ApiService _apiService = ApiService();

  /// Future that holds the list of chapters for the current manga.
  late Future<List<Map<String, dynamic>>> _chaptersFuture;

  /// Tracks download progress per chapter ID (0.0 to 1.0).
  final Map<String, double> _downloadProgress = {};

  /// Tracks chapter IDs that have been added to the download queue.
  final Set<String> _enqueuedIds = {};

  /// Whether the manga is marked as a favorite.
  bool _isFav = false;

  /// Whether bulk selection mode is active.
  bool _isBulkMode = false;

  /// Set of chapter IDs currently selected for bulk download.
  final Set<String> _selectedChapterIds = {};

  static const Color _purple = Color(0xFF4C04C9);

  @override
  void initState() {
    super.initState();

    /// Fetch chapters for this manga when the screen initializes.
    _chaptersFuture = _apiService.fetchChapters(widget.manga.id);
    _checkFavStatus();
  }

  /// Checks the database to see if this manga is saved as a favorite
  /// and updates the heart icon accordingly.
  void _checkFavStatus() async {
    bool fav = await DatabaseHelper().isFavorite(widget.manga.id);
    if (mounted) setState(() => _isFav = fav);
  }

  /// Opens a chapter for reading online.
  /// Shows a loading dialog while fetching page URLs,
  /// then navigates to ReaderScreen with the appropriate
  /// page transition animation from user settings.
  void _openChapter(String chapterId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pages = await _apiService.fetchPagesByChapterId(chapterId);
      final prefs = await SharedPreferences.getInstance();
      final String transitionType = prefs.getString('pageTransition') ?? "None";

      if (mounted) Navigator.pop(context);

      if (pages.isNotEmpty && mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 150),
            pageBuilder: (_, animation, __) => ReaderScreen(
              pageUrls: pages,
              mangaTitle: widget.manga.title,
              mangaId: widget.manga.id,
            ),
            transitionsBuilder: (_, animation, __, child) {
              final curved = CurvedAnimation(
                  parent: animation, curve: Curves.easeOutQuart);
              switch (transitionType) {
                case "Slide Up":
                  return SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 1), end: Offset.zero)
                          .animate(curved),
                      child: child);
                case "Slide Right":
                  return SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(1, 0), end: Offset.zero)
                          .animate(curved),
                      child: child);
                case "None":
                  return child;
                default:
                  return FadeTransition(opacity: curved, child: child);
              }
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  /// Fetches pages and genre for a single chapter then adds it
  /// to the DownloadService queue. Tracks progress and shows
  /// a checkmark when successfully enqueued.
  Future<void> _enqueueChapter(Map<String, dynamic> chap) async {
    final cId = chap['id'] as String;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _downloadProgress[cId] = 0.0);

    try {
      /// Fetch pages and genre simultaneously for efficiency.
      final results = await Future.wait([
        _apiService.fetchPagesByChapterId(cId),
        _apiService.fetchGenre(widget.manga.id),
      ]);
      final pages = results[0] as List<String>;
      final genre = results[1] as String;

      if (pages.isEmpty) throw Exception('No pages found.');

      DownloadService().downloadChapter(
        mangaId: widget.manga.id,
        mangaTitle: widget.manga.title,
        chapterId: cId,
        chapterNum: chap['chapter'].toString(),
        imageUrls: pages,
        coverUrl: widget.manga.coverUrl,
        genre: genre,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress[cId] = p);
        },
      );

      if (mounted) {
        setState(() {
          _downloadProgress.remove(cId);
          _enqueuedIds.add(cId);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress.remove(cId));
        messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  /// Downloads all chapters selected in bulk mode.
  /// Fetches pages for each selected chapter one by one,
  /// adds them to the download queue, and shows a snackbar
  /// with a link to the download queue when done.
  Future<void> _bulkDownload(List<Map<String, dynamic>> allChapters) async {
    if (_selectedChapterIds.isEmpty) return;

    final selected = allChapters
        .where((c) => _selectedChapterIds.contains(c['id']))
        .toList();

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isBulkMode = false;
      _selectedChapterIds.clear();
    });

    /// Fetch the genre once and reuse it for all chapters.
    String genre = 'Manga';
    try {
      genre = await _apiService.fetchGenre(widget.manga.id);
    } catch (_) {}

    int queued = 0;
    for (final chap in selected) {
      final cId = chap['id'] as String;
      try {
        final pages = await _apiService.fetchPagesByChapterId(cId);
        if (pages.isEmpty) continue;

        DownloadService().downloadChapter(
          mangaId: widget.manga.id,
          mangaTitle: widget.manga.title,
          chapterId: cId,
          chapterNum: chap['chapter'].toString(),
          imageUrls: pages,
          coverUrl: widget.manga.coverUrl,
          genre: genre,
          onProgress: (_) {},
        );

        if (mounted) setState(() => _enqueuedIds.add(cId));
        queued++;

        /// Small delay between requests to avoid rate limiting.
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {}
    }

    if (mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text('$queued chapters added to queue!',
            style: GoogleFonts.nunito()),
        action: SnackBarAction(
          label: 'View Queue',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DownloadQueueScreen())),
        ),
      ));
    }
  }

  /// Shows a bottom sheet with bulk download options:
  /// Download All, First 10, or Select Manually.
  void _showBulkOptions(List<Map<String, dynamic>> chapters) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Bulk Download',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 4),
            Text('${chapters.length} chapters available',
                style:
                    GoogleFonts.nunito(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 16),
            _bulkOption(
              icon: Icons.download_for_offline_rounded,
              color: _purple,
              label: 'Download All',
              subtitle: '${chapters.length} chapters',
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _isBulkMode = true;
                  _selectedChapterIds
                    ..clear()
                    ..addAll(chapters.map((c) => c['id'] as String));
                });
                _bulkDownload(chapters);
              },
            ),
            const SizedBox(height: 8),
            _bulkOption(
              icon: Icons.filter_1_rounded,
              color: Colors.blueAccent,
              label: 'First 10 Chapters',
              subtitle: 'Chapters 1–10',
              onTap: () {
                Navigator.pop(ctx);
                final first10 = chapters.take(10).toList();
                setState(() {
                  _isBulkMode = true;
                  _selectedChapterIds
                    ..clear()
                    ..addAll(first10.map((c) => c['id'] as String));
                });
                _bulkDownload(first10);
              },
            ),
            const SizedBox(height: 8),
            _bulkOption(
              icon: Icons.checklist_rounded,
              color: Colors.teal,
              label: 'Select Manually',
              subtitle: 'Pick chapters yourself',
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _isBulkMode = true;
                  _selectedChapterIds.clear();
                });
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Reusable styled list tile used inside the bulk download bottom sheet.
  Widget _bulkOption({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: color.withOpacity(0.07),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle,
          style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[500])),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
    );
  }

  /// Builds the main detail screen showing the manga cover,
  /// description, and a list of available chapters with
  /// download and bulk selection controls.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manga.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          /// Favorite toggle button — fills red when favorited.
          IconButton(
            icon: Icon(
              _isFav ? Icons.favorite : Icons.favorite_border,
              color: _isFav ? Colors.red : null,
            ),
            onPressed: () async {
              await DatabaseHelper().toggleFavorite({
                'id': widget.manga.id,
                'title': widget.manga.title,
                'thumbnail': widget.manga.coverUrl,
              });
              _checkFavStatus();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          /// Top section: manga cover image + scrollable description.
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: widget.manga.id,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      widget.manga.coverUrl,
                      width: 110,
                      height: 165,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 165,
                    child: SingleChildScrollView(
                      child: Text(
                        widget.manga.description,
                        style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          /// Bottom section: chapter list with bulk download controls.
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _chaptersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final chapters = snapshot.data ?? [];
                if (chapters.isEmpty) {
                  return Center(
                      child: Text('No chapters found.',
                          style: GoogleFonts.nunito(color: Colors.grey)));
                }

                return Column(
                  children: [
                    /// Header bar showing chapter count or selection count
                    /// with bulk mode toggle controls.
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Text(
                            _isBulkMode
                                ? '${_selectedChapterIds.length} selected'
                                : '${chapters.length} Chapters',
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const Spacer(),
                          if (_isBulkMode) ...[
                            /// Select all / deselect all toggle.
                            TextButton(
                              onPressed: () => setState(() {
                                if (_selectedChapterIds.length ==
                                    chapters.length) {
                                  _selectedChapterIds.clear();
                                } else {
                                  _selectedChapterIds.addAll(
                                      chapters.map((c) => c['id'] as String));
                                }
                              }),
                              child: Text(
                                _selectedChapterIds.length == chapters.length
                                    ? 'Deselect All'
                                    : 'Select All',
                                style: GoogleFonts.nunito(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),

                            /// Cancel bulk mode and clear selection.
                            TextButton(
                              onPressed: () => setState(() {
                                _isBulkMode = false;
                                _selectedChapterIds.clear();
                              }),
                              child: Text('Cancel',
                                  style: GoogleFonts.nunito(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ] else ...[
                            /// Opens the bulk download options bottom sheet.
                            TextButton.icon(
                              onPressed: () => _showBulkOptions(chapters),
                              icon: const Icon(Icons.download_for_offline,
                                  size: 16, color: _purple),
                              label: Text('Bulk',
                                  style: GoogleFonts.nunito(
                                      color: _purple,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ),
                          ],
                        ],
                      ),
                    ),

                    /// Confirm download button shown when chapters are selected.
                    if (_isBulkMode && _selectedChapterIds.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ElevatedButton.icon(
                          onPressed: () => _bulkDownload(chapters),
                          icon: const Icon(Icons.download_rounded,
                              color: Colors.white, size: 18),
                          label: Text(
                            'Download ${_selectedChapterIds.length} chapters',
                            style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _purple,
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                    /// Scrollable chapter list with per-chapter download
                    /// progress, enqueue status, and bulk checkbox support.
                    Expanded(
                      child: ListView.builder(
                        itemCount: chapters.length,
                        itemBuilder: (context, index) {
                          final chap = chapters[index];
                          final cId = chap['id'] as String;
                          final isDownloading =
                              _downloadProgress.containsKey(cId);
                          final isEnqueued = _enqueuedIds.contains(cId);
                          final isSelected = _selectedChapterIds.contains(cId);

                          return ListTile(
                            onTap: _isBulkMode
                                ? () => setState(() {
                                      if (isSelected) {
                                        _selectedChapterIds.remove(cId);
                                      } else {
                                        _selectedChapterIds.add(cId);
                                      }
                                    })
                                : () => _openChapter(cId),
                            leading: _isBulkMode
                                ? Checkbox(
                                    value: isSelected,
                                    activeColor: _purple,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4)),
                                    onChanged: (_) => setState(() {
                                      if (isSelected) {
                                        _selectedChapterIds.remove(cId);
                                      } else {
                                        _selectedChapterIds.add(cId);
                                      }
                                    }),
                                  )
                                : const Icon(Icons.menu_book, color: _purple),
                            title: Text(
                              'Chapter ${chap['chapter']}',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            subtitle: Text(
                              chap['title'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey),
                            ),
                            trailing: _isBulkMode
                                ? null
                                : Wrap(
                                    spacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      /// Shows circular progress, checkmark,
                                      /// or download button based on state.
                                      if (isDownloading)
                                        SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            value: _downloadProgress[cId],
                                            strokeWidth: 2.5,
                                            color: _purple,
                                          ),
                                        )
                                      else if (isEnqueued)
                                        const Icon(Icons.check_circle_rounded,
                                            color: Colors.green, size: 22)
                                      else
                                        IconButton(
                                          icon: const Icon(
                                              Icons.download_for_offline,
                                              color: _purple),
                                          onPressed: () =>
                                              _enqueueChapter(chap),
                                        ),
                                      const Icon(Icons.arrow_forward_ios,
                                          size: 14, color: Colors.grey),
                                    ],
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
