import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../services/database_helper.dart';
import 'reader_screen.dart';

class ChapterListOfflineScreen extends StatefulWidget {
  final String mangaTitle;
  const ChapterListOfflineScreen({super.key, required this.mangaTitle});

  @override
  State<ChapterListOfflineScreen> createState() =>
      _ChapterListOfflineScreenState();
}

class _ChapterListOfflineScreenState extends State<ChapterListOfflineScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Deletes a downloaded chapter from the database and removes
  /// its local folder and all image files from device storage.
  Future<void> _deleteChapter(Map<String, dynamic> ch) async {
    await _dbHelper.deleteDownload(ch['id']);
    final dir = Directory(ch['localPath']);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Chapter deleted")));
    }
  }

  /// Builds the main screen showing a list of downloaded chapters
  /// for the given manga title. Automatically pops back if no
  /// chapters are found in the database.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.mangaTitle,
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        /// Fetches all downloaded chapters for this manga from the DB.
        future: _dbHelper.getChaptersByManga(widget.mangaTitle),
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
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: chapters.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10),
            itemBuilder: (context, index) {
              final ch = chapters[index];
              return ListTile(
                leading: const Icon(Icons.menu_book, color: Colors.blueAccent),
                title: Text("Chapter ${ch['chapterNum']}",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
                subtitle: const Text("Downloaded Offline",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                trailing: IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteChapter(ch),
                ),
                onTap: () => _openReader(ch),
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
            path.endsWith('.webp'))
        .toList();

    /// Sort pages numerically by filename to ensure correct reading order.
    pages.sort((a, b) {
      int numA = int.parse(RegExp(r'\d+').stringMatch(p.basename(a)) ?? '0');
      int numB = int.parse(RegExp(r'\d+').stringMatch(p.basename(b)) ?? '0');
      return numA.compareTo(numB);
    });

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(pageUrls: pages, isOffline: true),
        ));
  }
}
