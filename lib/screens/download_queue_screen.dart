import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/download_service.dart';

class DownloadQueueScreen extends StatelessWidget {
  const DownloadQueueScreen({super.key});

  /// Builds the download queue screen which listens to the
  /// DownloadService queue and displays all active, queued,
  /// paused, and completed download tasks in real time.
  @override
  Widget build(BuildContext context) {
    final service = DownloadService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary; // Get accent color from theme

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text('Download Queue',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          /// Listens to queue changes and shows a Clear button
          /// only when there are pending or paused tasks.
          ValueListenableBuilder<List<DownloadTask>>(
            valueListenable: service.queueNotifier,
            builder: (context, queue, _) {
              final hasPending = queue
                  .any((t) => t.status == 'queued' || t.status == 'paused');
              if (!hasPending) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: service.clearQueue,
                icon: const Icon(Icons.clear_all,
                    color: Colors.redAccent, size: 18),
                label: Text('Clear',
                    style: GoogleFonts.nunito(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<DownloadTask>>(
        /// Rebuilds the list whenever the download queue changes.
        valueListenable: service.queueNotifier,
        builder: (context, queue, _) {
          /// Show empty state when no downloads are active.
          if (queue.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, // Use accentColor for empty state icon background
                    height: 80, // Use accentColor for empty state icon background
                    decoration: BoxDecoration( // Use accentColor for empty state icon background
                      color: accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle, // Use accentColor for empty state icon background
                    ),
                    child: Icon(Icons.download_done_rounded, // Use accentColor for empty state icon
                        size: 40, color: accentColor),
                  ),
                  const SizedBox(height: 16),
                  Text('No active downloads',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text('Downloads will appear here while in progress',
                      style: GoogleFonts.nunito(
                          color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            );
          }

          /// Renders each download task as a card in the list.
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: queue.length,
            itemBuilder: (context, index) =>
                _TaskCard(task: queue[index], service: service, isDark: isDark),
          );
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final DownloadTask task;
  final DownloadService service;
  final bool isDark;

  const _TaskCard({
    required this.task,
    required this.service,
    required this.isDark,
  });

  /// Builds a single download task card showing the manga title,
  /// chapter number, status, progress bar, and action buttons
  /// (pause, resume, cancel) based on the current task status.
  @override
  Widget build(BuildContext context) {
    final isDownloading = task.status == 'downloading';
    final isPaused = task.status == 'paused';
    final isDone = task.status == 'done';
    final isError = task.status == 'error';
    final isQueued = task.status == 'queued';

    /// Determine status color, icon, and label based on task state.
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (isDownloading) {
      statusColor = Theme.of(context).colorScheme.primary;
      statusIcon = Icons.downloading_rounded;
      statusLabel = 'Downloading...';
    } else if (isPaused) {
      statusColor = Colors.orangeAccent;
      statusIcon = Icons.pause_circle_outline_rounded;
      statusLabel = 'Paused — ${(task.progress * 100).toInt()}% done';
    } else if (isDone) {
      statusColor = Colors.greenAccent;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Complete';
    } else if (isError) {
      statusColor = Colors.redAccent;
      statusIcon = Icons.error_rounded;
      statusLabel = task.errorMessage.isNotEmpty ? task.errorMessage : 'Failed';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.hourglass_empty_rounded;
      statusLabel = 'Queued';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                /// Status icon box — color changes based on task state.
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),

                /// Manga title and chapter number.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.mangaTitle,
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chapter ${task.chapterNum}',
                        style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),

                /// Action buttons — shown conditionally based on task state.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// Pause button shown only when actively downloading.
                    if (isDownloading)
                      _circleBtn(
                        icon: Icons.pause_rounded,
                        color: Colors.orangeAccent,
                        onTap: () => service.pauseTask(task.chapterId),
                        tooltip: 'Pause',
                      ),

                    /// Resume button shown only when paused.
                    if (isPaused)
                      _circleBtn(
                        icon: Icons.play_arrow_rounded,
                        color: Colors.greenAccent,
                        onTap: () => service.resumeTask(task.chapterId),
                        tooltip: 'Resume',
                      ),
                    const SizedBox(width: 6),

                    /// Cancel button shown for queued, paused, or errored tasks.
                    if (isQueued || isPaused || isError)
                      _circleBtn(
                        icon: Icons.close_rounded,
                        color: Colors.redAccent,
                        onTap: () => service.cancelTask(task.chapterId),
                        tooltip: 'Cancel',
                      ),
                  ],
                ),
              ],
            ),

            /// Progress bar and page count shown during download or pause.
            if (isDownloading || isPaused) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: task.progress,
                  backgroundColor: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      isPaused ? Colors.orangeAccent : Theme.of(context).colorScheme.primary),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /// Status label on the left (e.g. "Downloading..." or "Paused").
                  Text(statusLabel,
                      style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),

                  /// Page progress on the right (e.g. "12/45 pages").
                  Text(
                    '${(task.progress * 100).toInt()}%  •  '
                    '${(task.resumeFromPage > 0 ? task.resumeFromPage : (task.progress * task.imageUrls.length).toInt())}/${task.imageUrls.length} pages',
                    style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ] else if (!isDone) ...[
              /// For queued or error states, just show the status label.
              const SizedBox(height: 8),
              Text(statusLabel,
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusColor)),
            ],
          ],
        ),
      ),
    );
  }

  /// Reusable circular icon button used for pause, resume, and cancel actions.
  Widget _circleBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}
