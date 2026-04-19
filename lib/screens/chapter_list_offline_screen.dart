import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import '../services/database_helper.dart';
import 'reader_screen.dart';

class ChapterListOfflineScreen extends StatefulWidget {
  final String mangaTitle;
  final String? mangaId;

  const ChapterListOfflineScreen({
    super.key,
    required this.mangaTitle,
    this.mangaId,
  });

  @override
  State<ChapterListOfflineScreen> createState() =>
      _ChapterListOfflineScreenState();
}

class _ChapterListOfflineScreenState extends State<ChapterListOfflineScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Deletes a downloaded chapter from the database and removes
  /// its local folder and all image files from device storage.
  Future<void> _deleteChapter(Map<String, dynamic> ch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1C1C2E)
            : Colors.white,
        title: Text('Delete Chapter', 
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want to delete Chapter ${ch['chapterNum']}? This will remove all pages from your device.',
          style: GoogleFonts.nunito(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.nunito(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.nunito(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _dbHelper.deleteDownload(ch['id']);
    final dir = Directory(ch['localPath']);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chapter deleted"), behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// Builds the main screen showing a list of downloaded chapters
  /// for the given manga title. Automatically pops back if no
  /// chapters are found in the database.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      appBar: AppBar(
        title: Text( // Kept title for sub-screen context
          widget.mangaTitle,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        /// Fetches all downloaded chapters for this manga from the DB.
        future: _dbHelper.getChaptersByManga(
          widget.mangaTitle,
          mangaId: widget.mangaId,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final chapters = snapshot.data!;

          /// If no chapters exist, automatically navigate back.
          if (chapters.isEmpty) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => Navigator.pop(context));
            return const SizedBox();
          }

          /// Renders the list of downloaded chapters with
          /// a delete button and tap-to-read functionality.
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final ch = chapters[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.menu_book_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                  ),
                  title: Text(
                    "Chapter ${ch['chapterNum']}",
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Icon(
                        Icons.offline_pin_rounded,
                        size: 12,
                        color: isDark ? Colors.greenAccent.withValues(alpha: 0.7) : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Downloaded Offline",
                        style: GoogleFonts.nunito(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                    onPressed: () => _deleteChapter(ch),
                  ),
                  onTap: () => _openReader(ch),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Opens the offline reader for a downloaded chapter.
  /// Reads all image files (.jpg, .png, .webp) from the chapter's
  /// local folder, sorts them by page number, then launches
  /// the ReaderScreen in offline mode.
  void _openReader(Map<String, dynamic> ch) {
    final Directory dir = Directory(ch['localPath']);
    if (!dir.existsSync()) return;

    /// Collect all valid image file paths from the chapter directory.
    List<String> pages = dir
        .listSync()
        .map((f) => f.path)
        .where((path) =>
            path.endsWith('.jpg') ||
            path.endsWith('.png') ||
            path.endsWith('.webp') ||
            RegExp(r'\d+$').hasMatch(p.basename(path))) // Recognize numeric extension-less files
        .toList();

    /// Sort pages numerically by filename to ensure correct reading order.
    pages.sort((a, b) {
      // Extract digits from the filename (e.g., "001" -> 1)
      final reg = RegExp(r'\d+');
      final matchA = reg.stringMatch(p.basename(a));
      final matchB = reg.stringMatch(p.basename(b));
      
      int numA = int.tryParse(matchA ?? '') ?? 0;
      int numB = int.tryParse(matchB ?? '') ?? 0;
      return numA.compareTo(numB);
    });

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            pageUrls: pages,
            isOffline: true,
            mangaTitle: widget.mangaTitle,
            mangaId: ch['mangaId']?.toString() ?? widget.mangaId ?? widget.mangaTitle.hashCode.toString(),
          ),
        ));
  }
}
