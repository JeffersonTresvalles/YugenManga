import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/reading_stats.dart';
import '../services/reading_stats_service.dart';
import '../services/favorites_service.dart';

/// Statistics screen displaying reading activity and personal stats.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late ReadingStatsService _statsService;
  late FavoritesService _favoritesService;
  ReadingStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _statsService = ReadingStatsService();
    _favoritesService = FavoritesService();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await _statsService.getReadingStats();
    // Sync favorites count with reading stats
    final favorites = await _favoritesService.getFavoritesStream().first;
    await _statsService.updateMangaInLibraryCount(favorites.length);

    // Reload stats after updating
    final updatedStats = await _statsService.getReadingStats();
    setState(() {
      _stats = updatedStats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = _stats ?? ReadingStats(userId: 'unknown');

    return Scaffold(
      appBar: AppBar(
        title: Text('Reading Statistics',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20)), // Kept title for sub-screen context
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Main Stats Grid
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _statCard(
                  context,
                  isDark,
                  icon: Icons.schedule,
                  title: 'Reading Time',
                  value: '${stats.getReadingHours()}h ${stats.getRemainingMinutes()}m',
                  color: const Color(0xFF5DADE2),
                ),
                _statCard(
                  context,
                  isDark,
                  icon: Icons.library_books,
                  title: 'Chapters Read',
                  value: stats.totalChaptersRead.toString(),
                  color: Theme.of(context).colorScheme.primary,
                ),
                _statCard(
                  context,
                  isDark,
                  icon: Icons.library_books,
                  title: 'Manga in Favorites',
                  value: stats.totalMangaInLibrary.toString(),
                  color: const Color(0xFFE91E63),
                ),
                _statCard(
                  context,
                  isDark,
                  icon: Icons.local_fire_department,
                  title: 'Reading Streak',
                  value: '${stats.readingStreak} days',
                  color: const Color(0xFFE74C3C),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Average Time Per Chapter
            _sectionLabel(context, 'READING METRICS'),
            _infoCard(isDark, [
              _metricRow(
                context,
                'Avg. Time per Chapter',
                '${stats.getAverageReadingTimePerChapter().toStringAsFixed(1)} min',
              ),
              const Divider(height: 16, indent: 0),
              _metricRow(
                context,
                'Most Read Manga',
                stats.mostReadMangaTitle.isEmpty
                    ? 'No data'
                    : stats.mostReadMangaTitle,
              ),
            ]),

            const SizedBox(height: 24),

            // Activity Heatmap
            _sectionLabel(context, 'READING ACTIVITY'),
            _buildHeatmap(context, isDark, stats),

            const SizedBox(height: 24),

            // Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reading Tips',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Maintain a reading streak by reading daily\n'
                    '• Your statistics sync across all devices\n'
                    '• Heatmap shows your reading frequency\n'
                    '• Time per chapter helps track progress',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.nunito(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _infoCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(children: children),
    );
  }

  Widget _metricRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmap(BuildContext context, bool isDark, ReadingStats stats) {
    const cellSize = 30.0;
    const spacing = 2.0;

    // Create a simplified heatmap for last 12 weeks (84 days)
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 83));
    final dailyData = stats.dailyReadingMinutes;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 12 Weeks',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(84, (index) {
                final date = startDate.add(Duration(days: index));
                final dateKey =
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final minutes = dailyData[dateKey] ?? 0;
                final intensity = ((minutes / 60) as double).clamp(0.0, 1.0);

                return Container(
                  width: cellSize,
                  height: cellSize,
                  decoration: BoxDecoration(
                    color: intensity == 0
                        ? (isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300)
                        : Color.lerp(
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            Theme.of(context).colorScheme.primary,
                            intensity,
                          ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                      width: 0.5,
                    ),
                  ),
                  child: Tooltip(
                    message: '$minutes min on ${date.day}/${date.month}',
                    child: const SizedBox.expand(),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              'Darker = more reading',
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
