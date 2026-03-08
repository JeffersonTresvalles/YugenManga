import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';
import 'chapter_list_offline_screen.dart';
import 'download_queue_screen.dart';
import '../services/download_service.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ApiService _apiService = ApiService();

  /// Future that holds the grouped list of downloaded manga.
  Future<List<Map<String, dynamic>>>? _downloadsFuture;

  /// Whether genres are currently being fetched from the API.
  bool _isRefreshingGenres = false;

  /// Currently selected genre filter chip.
  String _selectedGenre = 'All';

  /// List of genre filter options shown as chips.
  final List<String> _genres = [
    'All',
    'Action',
    'Romance',
    'Comedy',
    'Fantasy',
    'Horror',
    'Drama',
    'Adventure',
    'Sci-Fi',
    'Slice of Life',
  ];

  static const Color primaryPurple = Color(0xFF8E8FFA);

  @override
  void initState() {
    super.initState();

    /// Load downloaded manga when screen first opens.
    _loadDownloads();
  }

  /// Fetches the grouped downloads list from the database
  /// and triggers a UI rebuild.
  Future<void> _loadDownloads() async {
    setState(() {
      _downloadsFuture = _dbHelper.getDownloadsGroupedByManga();
    });
  }

  /// Fetches and updates missing genres for all downloaded manga
  /// by calling the API using the manga ID extracted from the local path.
  /// Shows a loading indicator in the app bar while running.
  Future<void> _refreshAllGenres() async {
    setState(() => _isRefreshingGenres = true);
    try {
      final all = await _dbHelper.getDownloads();
      final Map<String, String> mangaIdToTitle = {};

      for (final row in all) {
        final title = row['mangaTitle'] as String? ?? '';
        final genre = row['genre'] as String?;
        final localPath = row['localPath'] as String? ?? '';
        final parts = localPath.split('/');

        /// Extract manga ID from the second-to-last path segment.
        if (parts.length >= 2) {
          final mangaId = parts[parts.length - 2];
          if ((genre == null || genre.isEmpty) && mangaId.isNotEmpty) {
            mangaIdToTitle[mangaId] = title;
          }
        }
      }

      /// Fetch genre from API and update DB for each manga missing a genre.
      for (final entry in mangaIdToTitle.entries) {
        final genre = await _apiService.fetchGenre(entry.key);
        await _dbHelper.updateGenreByMangaTitle(entry.value, genre);
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingGenres = false);
        _loadDownloads();
      }
    }
  }

  /// Returns a color associated with the given genre string
  /// for use in genre badges and labels.
  Color _getGenreColor(String genre) {
    final g = genre.toLowerCase();
    if (g.contains('action')) return Colors.redAccent;
    if (g.contains('romance')) return Colors.pinkAccent;
    if (g.contains('comedy')) return Colors.orangeAccent;
    if (g.contains('horror')) return Colors.deepPurpleAccent;
    if (g.contains('fantasy')) return Colors.blueAccent;
    if (g.contains('sci-fi')) return Colors.tealAccent;
    if (g.contains('drama')) return Colors.yellowAccent;
    if (g.contains('adventure')) return Colors.greenAccent;
    return primaryPurple;
  }

  /// Builds a horizontal scrollable row of genre filter chips.
  /// Tapping a chip updates [_selectedGenre] to filter the manga grid.
  Widget _buildGenreChips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = _genres[index];
          final isSelected = _selectedGenre == genre;
          return GestureDetector(
            onTap: () => setState(() => _selectedGenre = genre),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryPurple
                    : (isDark
                        ? primaryPurple.withValues(alpha: 0.15)
                        : primaryPurple.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? primaryPurple
                      : primaryPurple.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                genre,
                style: GoogleFonts.nunito(
                  color: isSelected ? Colors.black : primaryPurple,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds the main downloads screen with a genre filter bar,
  /// a manga grid, and a floating action button to view the download queue.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      appBar: AppBar(
        title: Text('Offline Library',
            style:
                GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          /// Shows a loading spinner while genres are refreshing,
          /// otherwise shows the genre refresh button.
          _isRefreshingGenres
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.label_outline),
                  tooltip: 'Fetch genres',
                  onPressed: _refreshAllGenres,
                ),
        ],
      ),

      /// FAB shows queue count badge when downloads are active.
      floatingActionButton: ValueListenableBuilder<List<DownloadTask>>(
        valueListenable: DownloadService().queueNotifier,
        builder: (context, queue, _) {
          return FloatingActionButton.extended(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadQueueScreen()),
            ),
            backgroundColor: primaryPurple,
            icon: queue.isEmpty
                ? const Icon(Icons.download_rounded, color: Colors.black)
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.downloading_rounded,
                          color: Colors.black),

                      /// Red badge showing number of active downloads.
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${queue.length}',
                            style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
            label: Text(
              queue.isEmpty ? 'Queue' : '${queue.length} downloading',
              style: GoogleFonts.nunito(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          );
        },
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildGenreChips(),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _downloadsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: primaryPurple));
                }

                final mangaList = snapshot.data ?? [];

                /// Filter manga by selected genre chip.
                final filtered = mangaList
                    .where((m) =>
                        _selectedGenre == 'All' ||
                        (m['genre'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(_selectedGenre.toLowerCase()))
                    .toList();

                return RefreshIndicator(
                  onRefresh: _loadDownloads,
                  color: primaryPurple,
                  backgroundColor:
                      isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  child: filtered.isEmpty

                      /// Empty state shown when no downloads match the filter.
                      ? ListView(
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.22),
                            Center(
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: primaryPurple.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _selectedGenre == 'All'
                                      ? Icons.download_for_offline_outlined
                                      : Icons.filter_list_off_rounded,
                                  size: 44,
                                  color: primaryPurple.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Text(
                                _selectedGenre == 'All'
                                    ? 'No downloads yet.'
                                    : 'No $_selectedGenre downloads.',
                                style: GoogleFonts.nunito(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                _selectedGenre == 'All'
                                    ? 'Download chapters from the Search tab.'
                                    : 'Try selecting a different genre.',
                                style: GoogleFonts.nunito(
                                    color: isDark
                                        ? Colors.grey[600]
                                        : Colors.grey[400],
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        )

                      /// Grid of downloaded manga cards.
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.58,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 18,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) =>
                              _buildMangaCard(filtered[index]),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single manga card for the downloads grid showing
  /// the cover image, genre badge, chapter count, and title.
  /// Tapping navigates to the offline chapter list for that manga.
  Widget _buildMangaCard(Map<String, dynamic> manga) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.grey[200]!;
    final String title = manga['mangaTitle'] ?? 'Unknown';
    final String rawGenre = (manga['genre'] ?? '').toString();

    /// Use only the first genre if multiple are stored comma-separated.
    final String firstGenre =
        rawGenre.isNotEmpty ? rawGenre.split(',')[0].trim() : '';
    final String? dbPath = manga['coverPath'];
    final String? localPath = manga['localPath'];
    final int count = manga['chapterCount'] ?? 0;

    return GestureDetector(
      onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChapterListOfflineScreen(mangaTitle: title)))
          .then((_) => _loadDownloads()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: cardBg,
                    child: _getCoverWidget(dbPath, localPath),
                  ),

                  /// Dark gradient overlay at the bottom for badge readability.
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.9),
                        ],
                        stops: const [0.55, 1.0],
                      ),
                    ),
                  ),

                  /// Genre badge shown at bottom left of cover.
                  if (firstGenre.isNotEmpty)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getGenreColor(firstGenre)
                                .withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          firstGenre.toUpperCase(),
                          style: GoogleFonts.nunito(
                            color: _getGenreColor(firstGenre),
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  /// Chapter count badge shown at bottom right of cover.
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryPurple,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$count Ch.',
                        style: GoogleFonts.nunito(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: GoogleFonts.nunito(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves the cover image for a manga card.
  /// First tries the stored DB cover path, then falls back to
  /// the first image found in the chapter's local download folder.
  Widget _getCoverWidget(String? dbPath, String? localPath) {
    File? coverFile;

    /// Try loading cover from the stored DB path first.
    if (dbPath != null && dbPath.isNotEmpty) {
      final f = File(dbPath);
      if (f.existsSync()) coverFile = f;
    }

    /// Fall back to first image in the local chapter directory.
    if (coverFile == null && localPath != null) {
      try {
        final dir = Directory(localPath);
        if (dir.existsSync()) {
          final files = dir
              .listSync()
              .where((f) =>
                  f.path.toLowerCase().endsWith('.jpg') ||
                  f.path.toLowerCase().endsWith('.png'))
              .toList();
          if (files.isNotEmpty) {
            files.sort((a, b) => a.path.compareTo(b.path));
            coverFile = File(files.first.path);
          }
        }
      } catch (_) {}
    }

    if (coverFile != null && coverFile.existsSync()) {
      return Image.file(coverFile, fit: BoxFit.cover);
    }

    /// Show broken image icon if no cover is found.
    return const Center(
        child: Icon(Icons.broken_image, color: Colors.white10, size: 40));
  }
}
