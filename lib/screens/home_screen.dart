import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../services/theme_provider.dart';
import 'color_extensions.dart'; // Fixed path for the custom color extension
import '../models/manga.dart';
import '../services/api_service.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  /// Future holding the fetched manga list from the API.
  late Future<List<Manga>> _mangaList;

  /// Full list of manga returned from the API.
  List<Manga> _allMangas = [];

  /// Currently displayed manga list (filtered or full).
  List<Manga> _filteredMangas = [];

  @override
  void initState() {
    super.initState();

    /// Load manga when the screen first opens.
    _loadManga();
  }

  /// Fetches the manga list from the API and updates
  /// both [_allMangas] and [_filteredMangas] on success.
  void _loadManga() {
    _mangaList = _apiService.fetchMangaList();
    _mangaList.then((list) {
      if (mounted) {
        setState(() {
          _allMangas = list;
          _filteredMangas = list;
        });
      }
    });
  }

  /// Builds the home screen with a collapsible app bar,
  /// pull-to-refresh, and manga grid.
  @override
  Widget build(BuildContext context) {
    // Safe check for ThemeProvider to prevent Red Screen if Provider is missing
    Color accentColor;
    try {
      accentColor = Provider.of<ThemeProvider>(context).accentColor;
    } catch (e) {
      accentColor = Theme.of(context).colorScheme.primary;
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          /// Floating app bar without drawer, since navigation now lives in More.
          SliverAppBar(
            backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            floating: true,
            snap: true,
            centerTitle: false,
            title: Text('Library', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20)),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            _loadManga();
          },
          child: FutureBuilder<List<Manga>>(
            future: _mangaList,
            builder: (context, snapshot) {
              /// Show shimmer while loading and list is empty.
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _allMangas.isEmpty) {
                return _buildShimmerGrid();
              }

              /// Show error state if API call fails.
              if (snapshot.hasError) {
                return _buildEmptyState(
                  isDark: isDark,
                  accentColor: accentColor,
                  icon: Icons.wifi_off_rounded,
                  title: 'Connection error.',
                  subtitle: 'Pull down to retry.',
                );
              }

              /// Show empty state if no manga is available.
              if (_filteredMangas.isEmpty) {
                return _buildEmptyState(
                  isDark: isDark,
                  accentColor: accentColor,
                  icon: Icons.menu_book_outlined,
                  title: 'No manga found.',
                  subtitle: 'Pull down to refresh.',
                );
              }

              /// Render the manga grid when data is available.
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.72,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 14,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _MangaGridCard(manga: _filteredMangas[index]),
                        childCount: _filteredMangas.length,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Builds a centered empty/error state with an icon, title, and subtitle.
  Widget _buildEmptyState({
    required bool isDark,
    required Color accentColor,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration( // Use accentColor for the empty state icon background
              color: accentColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 44,
              color: accentColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.nunito(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 15,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.nunito(
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Builds a shimmer placeholder grid shown while manga is loading.
  Widget _buildShimmerGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _MangaGridCard extends StatelessWidget {
  final Manga manga;
  const _MangaGridCard({required this.manga});

  /// Builds a single manga card for the home grid.
  /// Shows the cover image with a gradient overlay and
  /// the title overlaid at the bottom. Tapping navigates
  /// to the DetailScreen for that manga.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => DetailScreen(manga: manga)));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.12),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            /// Cover image with placeholder and error fallback.
            CachedNetworkImage(
              imageUrl: manga.coverUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[200]),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.broken_image),
            ),

            /// Dark gradient overlay for title readability.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),

            /// Manga title overlaid at the bottom of the card.
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                manga.title,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
