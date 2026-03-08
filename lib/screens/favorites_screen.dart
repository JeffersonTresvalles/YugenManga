import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../services/database_helper.dart';
import '../services/api_service.dart';
import '../models/manga.dart';
import 'detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _dbHelper = DatabaseHelper();
  final _apiService = ApiService();

  /// Full list of favorited manga from the database.
  List<Map<String, dynamic>> _allFavs = [];

  /// Cache of fetched genres keyed by manga ID.
  final Map<String, String> _genreCache = {};

  /// Whether genres are currently being fetched in the background.
  bool _isLoadingGenres = false;

  /// Whether the initial favorites list is still loading.
  bool _isLoading = true;

  /// Currently selected genre filter chip.
  String _selectedGenre = 'All';

  /// Available genre filter options.
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

    /// Load favorites and fetch genres on screen init.
    _loadFavoritesAndGenres();
  }

  /// Loads all favorited manga from the database then
  /// triggers background genre fetching for any missing entries.
  Future<void> _loadFavoritesAndGenres() async {
    setState(() => _isLoading = true);
    final favs = await _dbHelper.getFavorites();
    if (!mounted) return;
    setState(() {
      _allFavs = favs;
      _isLoading = false;
    });
    _fetchMissingGenres(favs);
  }

  /// Fetches genres from the API for any favorites not yet
  /// in the genre cache. Updates the cache incrementally
  /// and shows a loading indicator while running.
  Future<void> _fetchMissingGenres(List<Map<String, dynamic>> favs) async {
    final missing = favs
        .where((f) => !_genreCache.containsKey(f['id']?.toString() ?? ''))
        .toList();
    if (missing.isEmpty) return;

    setState(() => _isLoadingGenres = true);
    for (final fav in missing) {
      final id = fav['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      try {
        final genre = await _apiService.fetchGenre(id);
        if (mounted) setState(() => _genreCache[id] = genre);
      } catch (_) {
        if (mounted) setState(() => _genreCache[id] = '');
      }
    }
    if (mounted) setState(() => _isLoadingGenres = false);
  }

  /// Returns favorites filtered by the currently selected genre chip.
  /// Returns all favorites if 'All' is selected.
  List<Map<String, dynamic>> get _filtered {
    if (_selectedGenre == 'All') return _allFavs;
    return _allFavs.where((fav) {
      final id = fav['id']?.toString() ?? '';
      final genre = (_genreCache[id] ?? '').toLowerCase();
      return genre.contains(_selectedGenre.toLowerCase());
    }).toList();
  }

  /// Returns a color associated with the given genre string
  /// for use in genre badges.
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
  /// Tapping a chip updates [_selectedGenre] to filter the grid.
  Widget _buildGenreChips(bool isDark) {
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
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedGenre = genre);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryPurple
                    : primaryPurple.withValues(alpha: isDark ? 0.15 : 0.08),
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

  /// Builds the favorites screen with a genre filter bar,
  /// pull-to-refresh, shimmer loading state, and manga grid.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Favorites',
            style:
                GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20)),
        centerTitle: true,
        actions: [
          /// Shows a spinner in the app bar while genres are loading.
          if (_isLoadingGenres)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildGenreChips(isDark),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.lightImpact();
                await _loadFavoritesAndGenres();
              },

              /// Show shimmer while loading, otherwise show content.
              child: _isLoading
                  ? _buildShimmerGrid(isDark)
                  : _buildContent(isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the main content area — shows an empty state if no favorites,
  /// a filtered empty state if genre has no matches, or the manga grid.
  Widget _buildContent(bool isDark) {
    final favs = _filtered;

    /// Empty state when no manga has been favorited yet.
    if (_allFavs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: primaryPurple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 44,
                color: primaryPurple.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Library is empty.',
              style: GoogleFonts.nunito(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Add some manga to your favorites!',
              style: GoogleFonts.nunito(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                  fontSize: 13),
            ),
          ),
        ],
      );
    }

    /// Empty state when selected genre filter has no matching favorites.
    if (favs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: primaryPurple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.filter_list_off_rounded,
                size: 44,
                color: primaryPurple.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'No $_selectedGenre manga found.',
              style: GoogleFonts.nunito(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Try selecting a different genre.',
              style: GoogleFonts.nunito(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                  fontSize: 13),
            ),
          ),
        ],
      );
    }

    /// Grid of favorited manga cards filtered by selected genre.
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: favs.length,
      itemBuilder: (context, index) {
        final fav = favs[index];
        final id = fav['id']?.toString() ?? '';
        final genre = _genreCache[id] ?? '';

        /// Use only the first genre if multiple are stored.
        final firstGenre = genre.isNotEmpty ? genre.split(',')[0].trim() : '';
        return _MangaCard(
          fav: fav,
          firstGenre: firstGenre,
          genreColor: firstGenre.isNotEmpty
              ? _getGenreColor(firstGenre)
              : primaryPurple,
          isDark: isDark,
          onReturn: _loadFavoritesAndGenres,
        );
      },
    );
  }

  /// Builds a shimmer placeholder grid shown while favorites are loading.
  Widget _buildShimmerGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _MangaCard extends StatelessWidget {
  final Map<String, dynamic> fav;
  final String firstGenre;
  final Color genreColor;
  final bool isDark;

  /// Callback to reload favorites after returning from detail screen.
  final VoidCallback onReturn;

  const _MangaCard({
    required this.fav,
    required this.firstGenre,
    required this.genreColor,
    required this.isDark,
    required this.onReturn,
  });

  /// Builds a single favorite manga card with cover image,
  /// gradient overlay, genre badge, and title.
  /// Tapping navigates to the DetailScreen for that manga.
  @override
  Widget build(BuildContext context) {
    final String mangaId = fav['id']?.toString() ?? '';
    final String mangaTitle = fav['title'] ?? 'No Title';
    final String mangaUrl = fav['thumbnail'] ?? '';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailScreen(
              /// Construct a Manga object from the stored favorite data.
              manga: Manga(
                id: mangaId,
                title: mangaTitle,
                description: 'Favorited Manga',
                rawCoverUrl: mangaUrl,
              ),
            ),
          ),
        ).then((_) => onReturn());
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.72,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  /// Cover image with shimmer placeholder and broken image fallback.
                  CachedNetworkImage(
                    imageUrl: mangaUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                      highlightColor:
                          isDark ? Colors.grey[700]! : Colors.grey[100]!,
                      child: Container(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),

                  /// Dark gradient overlay for badge readability.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
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
                            color: genreColor.withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          firstGenre.toUpperCase(),
                          style: GoogleFonts.nunito(
                            color: genreColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          /// Manga title below the cover image.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              mangaTitle,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
