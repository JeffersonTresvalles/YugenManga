import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderScreen extends StatefulWidget {
  final List<String> pageUrls;
  final bool isOffline;

  const ReaderScreen(
      {super.key, required this.pageUrls, this.isOffline = false});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  String _readingMode = "Vertical";
  bool _showControls = false;
  int _currentPage = 1;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadReadingMode();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadReadingMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _readingMode = prefs.getString('readMode') ?? "Vertical";
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.pageUrls.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            // Reader content
            widget.pageUrls.isEmpty
                ? Center(
                    child: Text('No pages found',
                        style: GoogleFonts.nunito(color: Colors.white)))
                : _buildReader(),

            // Top controls bar
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Reading',
                              style: GoogleFonts.nunito(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16),
                            ),
                          ),
                          // Page counter
                          if (total > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_currentPage / $total',
                                style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReader() {
    switch (_readingMode) {
      case "Webtoon":
      case "Vertical":
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Update page estimate for vertical scroll
            if (notification is ScrollUpdateNotification) {
              final itemH = MediaQuery.of(context).size.height;
              final page = (notification.metrics.pixels / itemH).floor() + 1;
              if (page != _currentPage &&
                  page >= 1 &&
                  page <= widget.pageUrls.length) {
                setState(() => _currentPage = page);
              }
            }
            return false;
          },
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: widget.pageUrls.length,
            itemBuilder: (context, index) =>
                _buildImage(widget.pageUrls[index]),
          ),
        );

      case "LTR":
        return PageView.builder(
          controller: _pageController,
          reverse: false,
          itemCount: widget.pageUrls.length,
          onPageChanged: (i) => setState(() => _currentPage = i + 1),
          itemBuilder: (context, index) =>
              InteractiveViewer(child: _buildImage(widget.pageUrls[index])),
        );

      case "RTL":
        return PageView.builder(
          controller: _pageController,
          reverse: true,
          itemCount: widget.pageUrls.length,
          onPageChanged: (i) => setState(() => _currentPage = i + 1),
          itemBuilder: (context, index) =>
              InteractiveViewer(child: _buildImage(widget.pageUrls[index])),
        );

      default:
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: widget.pageUrls.length,
          itemBuilder: (context, index) => _buildImage(widget.pageUrls[index]),
        );
    }
  }

  Widget _buildImage(String url) {
    return widget.isOffline
        ? Image.file(File(url), fit: BoxFit.contain)
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (context, url) => const SizedBox(
                height: 300,
                child: Center(
                    child: CircularProgressIndicator(color: Colors.white54))),
            errorWidget: (context, url, error) => const SizedBox(
              height: 200,
              child: Center(
                child:
                    Icon(Icons.broken_image, color: Colors.white30, size: 50),
              ),
            ),
          );
  }
}
