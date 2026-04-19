import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/manga.dart';
import '../services/api_service.dart';
import 'reader_screen.dart';
import '../services/download_service.dart';
import 'download_queue_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/favorites_service.dart';
import '../services/database_helper.dart'; // Import DatabaseHelper
import '../services/theme_provider.dart';

class DetailScreen extends StatefulWidget {
  final Manga manga;
  const DetailScreen({super.key, required this.manga});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ApiService _apiService = ApiService();
  final DownloadService _downloadService = DownloadService();
  final FavoritesService _favoritesService = FavoritesService();

  /// Future that holds the list of chapters for the current manga.
  late Future<List<Map<String, dynamic>>> _chaptersFuture;

  /// Tracks chapter IDs that are currently being prepared (fetching pages).
  final Set<String> _preparingIds = {};

  /// Whether the manga is in favorites.
  bool _isFavorite = false;

  /// Whether the manga is tracked.
  bool _isTracked = false;

  /// Whether description is expanded.
  bool _isDescriptionExpanded = false;

  /// Genres for display, fetched from manga model.
  List<String> _genres = [];

  /// Whether chapters are sorted in reverse.
  bool _isReversed = false;

  /// Local copy of the description to allow updating after API fetch.
  late String _description;

  @override
  void initState() {
    super.initState();
    _chaptersFuture = _apiService.fetchChapters(widget.manga.id);
    _checkFavoriteStatus();
    _genres = widget.manga.genres; // Use actual genres from Manga model
    // Debug: Print manga ID
    print('DetailScreen: Loading manga ${widget.manga.id} - ${widget.manga.title}');
    
    _description = widget.manga.description;
    
    // If the description is a placeholder, fetch the real one
    if (_description == "Favorited Manga" || _description == "No description available.") {
      _refreshMangaDetails();
    }
    
    // Listen to download queue changes to update UI progress
    _downloadService.queueNotifier.addListener(_updateUI);
  }

  Future<void> _refreshMangaDetails() async {
    final fullManga = await _apiService.fetchMangaById(widget.manga.id);
    if (fullManga != null && mounted) {
      setState(() {
        _description = fullManga.description;
        _genres = fullManga.genres;
      });
    }
  }

  @override
  void dispose() {
    _downloadService.queueNotifier.removeListener(_updateUI);
    super.dispose();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  /// Checks if manga is in favorites.
  void _checkFavoriteStatus() async {
    final isFav = await _favoritesService.isFavorite(widget.manga.id);
    if (mounted) setState(() => _isFavorite = isFav);
  }

  /// Opens a chapter for reading.
  void _openChapter(String chapterId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final pages = await _apiService.fetchPagesByChapterId(chapterId);
      if (pages.isEmpty) throw Exception('No pages found for this chapter');
      final prefs = await SharedPreferences.getInstance();
      final String transitionType = prefs.getString('pageTransition') ?? "None";

      if (mounted) Navigator.pop(context);

      if (pages.isNotEmpty && mounted) {
        // Enter full screen mode for reading
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

        await Navigator.push(
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

        // Restore system bars when returning from the reader
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load chapter: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Downloads a single chapter.
  Future<void> _downloadChapter(String chapterId, String chapterTitle, {bool silent = false}) async {
    if (_preparingIds.contains(chapterId)) return;
    if (_downloadService.queueNotifier.value.any((t) => t.chapterId == chapterId)) return;

    setState(() => _preparingIds.add(chapterId));

    try {
      // Fetch pages first
      final pages = await _apiService.fetchPagesByChapterId(chapterId);
      if (pages.isEmpty) throw Exception('Chapter contains no pages');

      final added = await _downloadService.downloadChapter(
        mangaId: widget.manga.id,
        mangaTitle: widget.manga.title,
        chapterId: chapterId,
        chapterNum: chapterTitle,
        imageUrls: pages,
        coverUrl: widget.manga.coverUrl,
        genre: 'Manga', // Would come from API
        onProgress: (_) {}, // Handled by queue listener
      );

      if (!silent && mounted && added) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "$chapterTitle" to download queue'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View Queue',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadQueueScreen()),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to download queue: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _preparingIds.remove(chapterId));
      }
    }
  }

  /// Downloads all chapters.
  void _showDownloadOptions() async {
    final accentColor = Provider.of<ThemeProvider>(context, listen: false).accentColor;
    final chapters = await _chaptersFuture;
    if (chapters.isEmpty) return;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Download Options",
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _buildOptionTile(Icons.filter_1, "Download next 10 chapters", accentColor, () => _downloadBatch(chapters, 10)),
            _buildOptionTile(Icons.filter_5, "Download next 50 chapters", accentColor, () => _downloadBatch(chapters, 50)),
            _buildOptionTile(Icons.all_inclusive, "Download all chapters", accentColor, () => _downloadBatch(chapters, chapters.length)),
            _buildOptionTile(Icons.edit_note, "Manually select how many", accentColor, () => _showManualDownloadDialog(chapters)),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, Color accentColor, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: accentColor),
      title: Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _downloadBatch(List<Map<String, dynamic>> chapters, int count) {
    int enqueued = 0;
    for (int i = 0; i < chapters.length && enqueued < count; i++) {
      final chap = chapters[i];
      final id = chap['id'] as String?;
      if (id == null) continue;

      final title = chap['title'] as String? ?? 'Chapter ${chap['chapter'] ?? (i + 1)}';
      _downloadChapter(id, title, silent: true);
      enqueued++;
    }
    
    if (enqueued > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enqueued $enqueued chapters'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showManualDownloadDialog(List<Map<String, dynamic>> chapters) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C2E) : Colors.white,
        title: Text("Download Count", style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter number of chapters"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              Navigator.pop(context);
              if (val > 0) _downloadBatch(chapters, val);
            },
            child: const Text("Download"),
          ),
        ],
      ),
    );
  }

  /// Toggles favorite status.
  void _toggleFavorite() async {
    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }

    try {
      final newFavoriteStatus = await _favoritesService.toggleFavorite(
        mangaId: widget.manga.id,
        title: widget.manga.title,
        coverUrl: widget.manga.coverUrl,
        author: 'Unknown', // Would come from API
        status: 'Ongoing', // Would come from API
        source: 'MangaDex', // Default source
      );

      setState(() => _isFavorite = newFavoriteStatus);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newFavoriteStatus ? 'added to the favorites' : 'removed from the favorites'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update library: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C2E),
        title: Text(
          'Login Required',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Please log in to save manga to your library',
          style: GoogleFonts.nunito(
            color: Colors.white70,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(
                color: Colors.white54,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to login screen
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: Text(
              'Login',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Toggles tracking status.
  void _toggleTracking() {
    setState(() => _isTracked = !_isTracked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isTracked ? 'Now tracking' : 'Stopped tracking'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Opens manga in web view.
  void _openWebView() async {
    final Uri url = Uri.parse('https://mangadex.org/title/${widget.manga.id}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch browser')),
        );
      }
    }
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C2E) : Colors.white,
        title: Text('Report Issue', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: Text('Is there an issue with this manga or its chapters?', style: GoogleFonts.nunito()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted. Thank you!')),
              );
            },
            child: const Text('Report', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = themeProvider.accentColor;
    final Color currentTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
            onSelected: (value) {
              switch (value) {
                case 'share':
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sharing "${widget.manga.title}"...'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  break;
                case 'report':
                  _showReportDialog();
                  break;
                case 'webview':
                  _openWebView();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Text('Share'),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Text('Report'),
              ),
              const PopupMenuItem(
                value: 'webview',
                child: Text('Open in Browser'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: widget.manga.coverUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[900]),
              errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.8)),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Manga header with cover and info
                _buildMangaHeader(currentTextColor, accentColor),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildFavoriteButton(isDark, accentColor),
                      const SizedBox(width: 12),
                      _buildDownloadButton(accentColor),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Scrollable content
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: _buildMainContent(isDark, Theme.of(context).cardColor, currentTextColor, accentColor),
                  ),
                ),
              ],
            ),
          ),

          // Floating Start/Resume button
          Positioned(
            bottom: 24,
            right: 24,
            child: _buildFloatingResumeButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildMangaHeader(Color textColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover image with better styling
          Container(
            width: 130,
            height: 195,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: widget.manga.coverUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Shimmer.fromColors(
                  baseColor: Colors.grey[900]!,
                  highlightColor: Colors.grey[800]!,
                  child: Container(color: Colors.black),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[900],
                  child: const Icon(Icons.broken_image, color: Colors.white54),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Manga info with icons
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.manga.title,
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.person_outline, widget.manga.author, textColor, accentColor),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.update, 'Ongoing', textColor, accentColor),
                const SizedBox(height: 6),
                _buildInfoRow(Icons.library_books_outlined, 'MangaDex', textColor, accentColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color textColor, Color accentColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accentColor.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: textColor.withValues(alpha: 0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteButton(bool isDark, Color accentColor) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _isFavorite ? accentColor : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isFavorite ? accentColor : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: IconButton(
        onPressed: _toggleFavorite,
        icon: Icon(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          color: _isFavorite ? Colors.black : (isDark ? Colors.white : Colors.black),
          size: 26,
        ),
      ),
    );
  }

  Widget _buildDownloadButton(Color accentColor) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: _showDownloadOptions,
        icon: const Icon(Icons.download_for_offline, size: 22),
        label: Text(
          'Download Chapters',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(bool isDark, Color currentCardColor, Color currentTextColor, Color accentColor) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
      children: [
        // Description section
        Text(
          'Description',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: currentTextColor,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _description,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.6,
              ),
              maxLines: _isDescriptionExpanded ? null : 3,
              overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
        ),
        if (!_isDescriptionExpanded && _description.length > 150)
          TextButton(
            onPressed: () => setState(() => _isDescriptionExpanded = true),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
            child: Text(
              'Read more',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

        const SizedBox(height: 32),

        // Genres Chips
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _genres.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  _genres[index],
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 32),

        // Chapters Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Chapters',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: currentTextColor,
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _isReversed = !_isReversed),
              icon: Icon(_isReversed ? Icons.arrow_upward : Icons.arrow_downward, color: accentColor),
              tooltip: 'Sort Chapters',
            ),
          ],
        ),
        const SizedBox(height: 16),

        FutureBuilder<List<Map<String, dynamic>>>(
          future: _chaptersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            var chapters = snapshot.data ?? [];
            if (chapters.isEmpty) return const SizedBox.shrink();

            if (_isReversed) {
              chapters = chapters.reversed.toList();
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chapters.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final chapterId = chapter['id'] as String;
                final chapterTitle = chapter['title'] as String;
                
                final task = _downloadService.queueNotifier.value.cast<DownloadTask?>().firstWhere((t) => t?.chapterId == chapterId, orElse: () => null);
                final isPreparing = _preparingIds.contains(chapterId);
                final isEnqueued = task != null;
                final progress = task?.progress;

                return Container(
                  decoration: BoxDecoration(
                    color: currentCardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      chapterTitle,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: currentTextColor,
                      ),
                    ),
                    subtitle: Text(
                      'Scanlator • 2 days ago',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    trailing: _buildChapterAction(chapterId, chapterTitle, isPreparing, isEnqueued, progress, accentColor),
                    onTap: () => _openChapter(chapterId),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildChapterAction(String id, String title, bool isPreparing, bool isEnqueued, double? progress, Color accentColor) {
    if (isPreparing) {
      return const SizedBox(
        width: 24, height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.orange)),
      );
    }
    if (isEnqueued) {
      return SizedBox(
        width: 28, height: 28,
        child: CircularProgressIndicator(
          value: progress,
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation(accentColor),
          backgroundColor: Colors.white.withValues(alpha: 0.1),
        ),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(Icons.download_rounded, size: 22, color: isDark ? Colors.white : Colors.black),
      onPressed: () => _downloadChapter(id, title),
    );
  }

  Widget _buildFloatingResumeButton() {
    final accentColor = Provider.of<ThemeProvider>(context).accentColor;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _chaptersFuture,
      builder: (context, snapshot) {
        final chapters = snapshot.data ?? [];
        if (chapters.isEmpty) return const SizedBox.shrink();

        return FloatingActionButton.extended(
          onPressed: () => _openChapter(chapters.first['id']),
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.play_arrow_rounded, size: 28),
          label: Text(
            'Read Now',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        );
      },
    );
  }
}