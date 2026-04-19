import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_provider.dart';
import '../services/reading_stats_service.dart';

class ReaderScreen extends StatefulWidget {
  final List<String> pageUrls;
  final bool isOffline;
  final String? mangaTitle;
  final String? mangaId;

  const ReaderScreen({
    super.key,
    required this.pageUrls,
    this.isOffline = false,
    this.mangaTitle,
    this.mangaId,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const List<String> _readerModes = ['LTR', 'RTL', 'Vertical', 'Webtoon'];

  String _readingMode = 'Vertical';
  bool _showControls = false;
  int _currentPage = 1;
  late PageController _pageController;
  late ReadingStatsService _statsService;
  DateTime? _startTime;
  bool _chapterCompleted = false;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _statsService = ReadingStatsService();
    _startTime = DateTime.now();
    _loadReadingMode();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _saveReadingStats();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadReadingMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _readingMode = prefs.getString('readMode') ?? 'Vertical';
    });
  }

  Future<void> _saveReadingMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('readMode', mode);
  }

  Future<void> _saveReadingStats() async {
    if (_startTime == null) return;

    final endTime = DateTime.now();
    final readingDuration = endTime.difference(_startTime!);
    final minutesRead = readingDuration.inMinutes;

    if (minutesRead > 0) {
      await _statsService.addReadingTime(minutesRead);
    }

    if (_chapterCompleted && widget.mangaTitle != null && widget.mangaId != null) {
      await _statsService.incrementChaptersRead();
      await _statsService.updateMostReadManga(widget.mangaTitle!, widget.mangaId!);
      await _statsService.updateReadingStreak();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _hideControlsTimer?.cancel();
      _hideControlsTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _onPageChanged(int page) {
    final pageIndex = page + 1;
    setState(() => _currentPage = pageIndex);

    if (pageIndex == widget.pageUrls.length && !_chapterCompleted) {
      _chapterCompleted = true;
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
        _navigateToPreviousPage();
      } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
        _navigateToNextPage();
      }
    }
  }

  void _navigateToNextPage() {
    if (_currentPage < widget.pageUrls.length) {
      final newPage = _currentPage + 1;
      if (_readingMode == 'LTR' || _readingMode == 'RTL') {
        _pageController.jumpToPage(newPage - 1);
      }
      setState(() => _currentPage = newPage);
    }
  }

  void _navigateToPreviousPage() {
    if (_currentPage > 1) {
      final newPage = _currentPage - 1;
      if (_readingMode == 'LTR' || _readingMode == 'RTL') {
        _pageController.jumpToPage(newPage - 1);
      }
      setState(() => _currentPage = newPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.pageUrls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: _handleKey,
        child: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              widget.pageUrls.isEmpty
                  ? Center(
                      child: Text('No pages found',
                          style: GoogleFonts.nunito(color: Colors.white)))
                  : _buildReader(),
              if (_showControls) _buildTopBar(total),
              if (_showControls) _buildBottomBar(total),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(int total) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.mangaTitle ?? 'Reader',
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Page $_currentPage of $total • $_readingMode mode',
                        style: GoogleFonts.nunito(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: Colors.grey[900],
                  icon: const Icon(Icons.menu, color: Colors.white),
                  itemBuilder: (context) => _readerModes
                      .map((mode) => PopupMenuItem<String>(
                            value: mode,
                            child: Row(
                              children: [
                                Icon(
                                  _readingMode == mode
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(mode,
                                    style: GoogleFonts.nunito(
                                        color: Colors.white)),
                              ],
                            ),
                          ))
                      .toList(),
                  onSelected: (value) async {
                    await _saveReadingMode(value);
                    setState(() {
                      _readingMode = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(int total) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Builder(
                    builder: (context) => LinearProgressIndicator(
                      value: total > 0 ? _currentPage / total : 0,
                      color: Provider.of<ThemeProvider>(context).accentColor,
                      backgroundColor: Colors.white12,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _controlButton(
                      icon: Icons.first_page,
                      label: 'Start',
                      onTap: () {
                        if (_readingMode == 'LTR' || _readingMode == 'RTL') {
                          _pageController.jumpToPage(0);
                        }
                        setState(() => _currentPage = 1);
                      },
                    ),
                    const SizedBox(width: 8),
                    _controlButton(
                      icon: Icons.chevron_left,
                      label: 'Prev',
                      onTap: _navigateToPreviousPage,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Page $_currentPage / $total',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                            color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _controlButton(
                      icon: Icons.chevron_right,
                      label: 'Next',
                      onTap: _navigateToNextPage,
                    ),
                    const SizedBox(width: 8),
                    _controlButton(
                      icon: Icons.last_page,
                      label: 'End',
                      onTap: () {
                        if (_readingMode == 'LTR' || _readingMode == 'RTL') {
                          _pageController.jumpToPage(total - 1);
                        }
                        setState(() => _currentPage = total);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Double-tap to zoom • Tap to hide controls',
                      style: GoogleFonts.nunito(
                          color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      _readingMode == 'Webtoon'
                          ? 'Continuous webtoon'
                          : _readingMode == 'Vertical'
                              ? 'Vertical scroll'
                              : _readingMode == 'RTL'
                                  ? 'Right-to-left'
                                  : 'Left-to-right',
                      style: GoogleFonts.nunito(
                          color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.nunito(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReader() {
    switch (_readingMode) {
      case 'Webtoon':
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              final itemH = MediaQuery.of(context).size.height;
              final page = (notification.metrics.pixels / itemH).floor() + 1;
              if (page != _currentPage &&
                  page >= 1 &&
                  page <= widget.pageUrls.length) {
                _onPageChanged(page);
              }
            }
            return false;
          },
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            cacheExtent: MediaQuery.of(context).size.height * 3,
            padding: EdgeInsets.zero,
            itemCount: widget.pageUrls.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: InteractiveViewer(
                maxScale: 4.0,
                child: _buildImage(widget.pageUrls[index], fitMode: BoxFit.fitWidth),
              ),
            ),
          ),
        );

      case 'Vertical':
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              final itemH = MediaQuery.of(context).size.height;
              final page = (notification.metrics.pixels / itemH).floor() + 1;
              if (page != _currentPage &&
                  page >= 1 &&
                  page <= widget.pageUrls.length) {
                _onPageChanged(page);
              }
            }
            return false;
          },
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            cacheExtent: MediaQuery.of(context).size.height * 3,
            padding: EdgeInsets.zero,
            itemCount: widget.pageUrls.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: InteractiveViewer(
                maxScale: 4.0,
                child: _buildImage(widget.pageUrls[index], fitMode: BoxFit.contain),
              ),
            ),
          ),
        );

      case 'LTR':
        return PageView.builder(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          reverse: false,
          itemCount: widget.pageUrls.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) => InteractiveViewer(
            maxScale: 4.0,
            child: _buildImage(widget.pageUrls[index], fitMode: BoxFit.contain),
          ),
        );

      case 'RTL':
        return PageView.builder(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          reverse: true,
          itemCount: widget.pageUrls.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) => InteractiveViewer(
            maxScale: 4.0,
            child: _buildImage(widget.pageUrls[index], fitMode: BoxFit.contain),
          ),
        );

      default:
        return ListView.builder(
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          cacheExtent: MediaQuery.of(context).size.height * 3,
          padding: EdgeInsets.zero,
          itemCount: widget.pageUrls.length,
          itemBuilder: (context, index) => _buildImage(widget.pageUrls[index], fitMode: BoxFit.contain),
        );
    }
  }

  Widget _buildImage(String url, {BoxFit fitMode = BoxFit.contain}) {
    final accentColor = Provider.of<ThemeProvider>(context).accentColor;
    return widget.isOffline
        ? Image.file(File(url), fit: fitMode)
        : CachedNetworkImage(
            imageUrl: url,
            fit: fitMode,
            placeholder: (context, url) => Container(
                height: 300,
                color: Colors.black,
                  child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Provider.of<ThemeProvider>(context).accentColor,
                          )))),
            errorWidget: (context, url, error) => Container(
              height: 200,
              color: Colors.black,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.white30, size: 50),
              ),
            ),
          );
  }
}
