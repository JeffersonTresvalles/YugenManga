import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();

  /// List of manga results from the last search query.
  List<Manga> _results = [];

  /// Whether a search is currently in progress.
  bool _isLoading = false;

  /// Whether the user has performed at least one search.
  bool _hasSearched = false;

  /// Holds the error message if the search fails.
  String? _error;

  /// Performs a manga search using the current text field value.
  /// Updates [_results], [_isLoading], and [_error] based on the outcome.
  void _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      final results = await _apiService.searchManga(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Builds the search screen with a search text field,
  /// and a results area that shows loading, empty, error,
  /// or manga list states depending on current search status.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final inputFill = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = scheme.onSurface;
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text('Search',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 4),

            /// Search text field with clear button and keyboard submit support.
            TextField(
              controller: _controller,
              style: GoogleFonts.nunito(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search manga...',
                hintStyle:
                    GoogleFonts.nunito(color: subtitleColor, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: subtitleColor),

                /// Clear button resets results and search state.
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear, color: scheme.primary),
                  onPressed: () {
                    _controller.clear();
                    setState(() {
                      _results = [];
                      _hasSearched = false;
                      _error = null;
                    });
                  },
                ),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: isDark 
                          ? Colors.white.withOpacity(0.06) 
                          : Colors.black.withOpacity(0.07)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: scheme.primary, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),

            /// Results area — conditionally renders based on search state.
            Expanded(
              child: _isLoading

                  /// Loading spinner while search is in progress.
                  ? Center(
                      child: CircularProgressIndicator(color: scheme.primary))
                  : _error != null

                      /// Error state if the API call fails.
                      ? _buildEmptyState(Icons.error_outline, 'Error: $_error')
                      : !_hasSearched

                          /// Default state before any search is made.
                          ? _buildEmptyState(Icons.search_rounded,
                              'Discover your next favorite manga')
                          : _results.isEmpty

                              /// No results found for the query.
                              ? _buildEmptyState(Icons.sentiment_dissatisfied,
                                  'No results found')

                              /// Scrollable list of search result cards.
                              : ListView.builder(
                                  itemCount: _results.length,
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) =>
                                      _buildMangaTile(_results[index]),
                                ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single search result card showing the manga cover,
  /// title, and description. Tapping navigates to the DetailScreen.
  Widget _buildMangaTile(Manga manga) {
    /// Re-derive colors from context on every rebuild
    /// to ensure correct theme colors are always used.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Card(
      color: cardBg,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),

        /// Manga cover image with placeholder and error fallback.
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: manga.coverUrl,
            width: 50,
            height: 75,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: isDark ? Colors.white10 : Colors.grey[200]),
            errorWidget: (context, url, error) => Container(
              width: 50,
              height: 75,
              color: isDark ? Colors.white10 : Colors.grey[200],
              child:
                  const Icon(Icons.broken_image, size: 20, color: Colors.grey),
            ),
          ),
        ),
        title: Text(
          manga.title,
          style: GoogleFonts.nunito(
              color: textColor, fontWeight: FontWeight.w700, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          manga.description.isNotEmpty
              ? manga.description
              : 'No description available',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(
              color: subtitleColor, fontSize: 12, fontWeight: FontWeight.w400),
        ),
        trailing: Icon(Icons.chevron_right, color: subtitleColor, size: 20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(manga: manga)),
        ),
      ),
    );
  }

  /// Builds a centered empty/error state with an icon and message.
  /// Used for pre-search, no results, and error conditions.
  Widget _buildEmptyState(IconData icon, String message) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child:
                Icon(icon, size: 38, color: scheme.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: GoogleFonts.nunito(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
