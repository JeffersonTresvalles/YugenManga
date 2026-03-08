import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
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

  static const Color primaryPurple = Color(0xFF8E8FFA);

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
  /// side drawer, pull-to-refresh, and manga grid.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      drawer: _buildDrawer(isDark),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          /// Floating app bar with hamburger menu button.
          SliverAppBar(
            backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            floating: true,
            snap: true,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Scaffold.of(context).openDrawer();
                },
              ),
            ),
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
                  icon: Icons.wifi_off_rounded,
                  title: 'Connection error.',
                  subtitle: 'Pull down to retry.',
                );
              }

              /// Show empty state if no manga is available.
              if (_filteredMangas.isEmpty) {
                return _buildEmptyState(
                  isDark: isDark,
                  icon: Icons.menu_book_outlined,
                  title: 'No manga found.',
                  subtitle: 'Pull down to refresh.',
                );
              }

              /// Render the manga grid when data is available.
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                ),
                itemCount: _filteredMangas.length,
                itemBuilder: (context, index) =>
                    _MangaGridCard(manga: _filteredMangas[index]),
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
            decoration: BoxDecoration(
              color: primaryPurple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 44,
              color: primaryPurple.withValues(alpha: 0.4),
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

  /// Builds the side drawer showing the app header, disclaimer,
  /// team members, and a Ko-fi support link.
  Widget _buildDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF151515) : Colors.white,
      child: Column(
        children: [
          /// Gradient header with app icon and name.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4C04C9), Color(0xFF3949AB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                Text('YugenManga',
                    style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                Text('v1.0.0',
                    style: GoogleFonts.nunito(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                /// Disclaimer card shown at the top of the drawer.
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.deepPurple.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.deepPurple, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Inspired by Tachiyomi. This is an independent, non-commercial app for personal use only. It does not host any content and is not affiliated with any manga sources or publishers.',
                          style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: Colors.deepPurple,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text('MEET THE TEAM',
                      style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.grey[500])),
                ),

                /// Team member tiles.
                _teamTile(
                    'Jefferson Tresvalles', Icons.terminal, Colors.deepPurple),
                _teamTile('Karl Ioseff Tivar', Icons.code, Colors.blue),
                _teamTile('Louwie Jay Torres', Icons.architecture, Colors.pink),
                _teamTile('Justine Hendry Zafe', Icons.brush, Colors.orange),
                const SizedBox(height: 8),
                Divider(color: Colors.grey.withValues(alpha: 0.15)),
                const SizedBox(height: 4),

                /// Ko-fi support link tile.
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.brown.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        const Icon(Icons.coffee, color: Colors.brown, size: 18),
                  ),
                  title: Text('Support the Team',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text('ko-fi.com/teamkengkoy',
                      style:
                          GoogleFonts.nunito(fontSize: 11, color: Colors.grey)),
                  onTap: () => launchUrl(
                      Uri.parse('https://ko-fi.com/teamkengkoy'),
                      mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single team member tile with an icon and name.
  Widget _teamTile(String name, IconData icon, Color color) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      title: Text(name,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w600, fontSize: 13)),
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
        HapticFeedback.selectionClick();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => DetailScreen(manga: manga)));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
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
                      Colors.black.withValues(alpha: 0.85),
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
