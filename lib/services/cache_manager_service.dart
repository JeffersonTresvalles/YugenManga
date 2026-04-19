import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages the hidden manga cache directory for storing downloaded manga images.
/// 
/// By using the `.yugen_manga` folder name (starting with a dot) and including
/// a .nomedia file, the Android media scanner will completely ignore these
/// images, keeping manga downloads hidden from the Gallery/Photos app.
class CacheManagerService {
  CacheManagerService._();
  static final CacheManagerService instance = CacheManagerService._();

  static const String _cacheDirectoryName = '.yugen_data';
  static const String _chaptersCacheName = 'chapters';
  static const String _imagesCacheName = 'images';

  String _sanitizeFolderName(String input) {
    final sanitized = input
        .replaceAll(RegExp(r'[<>:"\/\\|?*]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        .trim();
    return sanitized.isEmpty ? 'manga' : sanitized;
  }

  /// Gets or creates the main hidden manga cache directory.
  /// 
  /// Returns: `<ApplicationSupportDirectory>/.yugen_data`
  Future<Directory> getMainCacheDirectory() async {
    final docsDir = await getApplicationSupportDirectory();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    // Scope the cache directory by User ID
    final cacheDir = Directory('${docsDir.path}/$_cacheDirectoryName/$uid');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
      await _createNomediaFile(cacheDir);
      print('CacheManager: Created main cache directory: ${cacheDir.path}');
    } else {
      await _ensureNomediaFile(cacheDir);
      print('CacheManager: Main cache directory exists: ${cacheDir.path}');
    }
    
    return cacheDir;
  }

  /// Gets or creates the chapters cache subdirectory.
  ///
  /// Returns: `<ApplicationSupportDirectory>/.yugen_data/chapters`
  Future<Directory> getChaptersCacheDirectory() async {
    final mainCache = await getMainCacheDirectory();
    final chaptersDir = Directory('${mainCache.path}/$_chaptersCacheName');
    
    if (!await chaptersDir.exists()) {
      await chaptersDir.create(recursive: true);
    }
    
    return chaptersDir;
  }

  /// Gets or creates the images cache subdirectory.
  /// 
  /// Returns: `<ApplicationDocumentsDirectory>/.manga_cache/images`
  Future<Directory> getImagesCacheDirectory() async {
    final mainCache = await getMainCacheDirectory();
    final imagesDir = Directory('${mainCache.path}/$_imagesCacheName');
    
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    
    return imagesDir;
  }

  /// Gets the manga-specific cache directory by title.
  /// 
  /// Returns: `<ApplicationDocumentsDirectory>/.manga_cache/chapters/<mangaTitle>`
  Future<Directory> getMangaCacheDirectory(String mangaTitle) async {
    final chaptersDir = await getChaptersCacheDirectory();
    final sanitizedTitle = _sanitizeFolderName(mangaTitle);
    final mangaDir = Directory(p.join(chaptersDir.path, sanitizedTitle));
    
    if (!await mangaDir.exists()) {
      await mangaDir.create(recursive: true);
    }
    
    return mangaDir;
  }

  /// Gets the specific chapter cache directory.
  /// 
  /// Returns: `<ApplicationDocumentsDirectory>/.manga_cache/chapters/<mangaTitle>/<chapterId>`
  Future<Directory> getChapterCacheDirectory(
    String mangaTitle,
    String chapterId,
  ) async {
    final mangaDir = await getMangaCacheDirectory(mangaTitle);
    final chapterDir = Directory('${mangaDir.path}/$chapterId');
    
    if (!await chapterDir.exists()) {
      await chapterDir.create(recursive: true);
      print('CacheManager: Created chapter cache directory: ${chapterDir.path}');
    } else {
      print('CacheManager: Chapter cache directory exists: ${chapterDir.path}');
    }
    
    return chapterDir;
  }

  /// Calculates the total size of the cache directory.
  /// Returns size in bytes.
  Future<int> getCacheSizeInBytes() async {
    final cacheDir = await getMainCacheDirectory();
    return _getTotalSizeOfDirectory(cacheDir);
  }

  /// Test method to verify cache manager is working correctly
  Future<void> testCacheManager() async {
    try {
      print('CacheManager: Testing cache manager functionality...');
      
      final mainDir = await getMainCacheDirectory();
      print('CacheManager: Main cache directory: ${mainDir.path}');
      
      final testDir = await getChapterCacheDirectory('Test Manga', 'test-chapter-001');
      print('CacheManager: Test chapter directory: ${testDir.path}');
      
      // Create a test file
      final testFile = File('${testDir.path}/test.txt');
      await testFile.writeAsString('Test content');
      print('CacheManager: Test file created: ${testFile.path}');
      
      // Check if file exists
      final exists = await testFile.exists();
      print('CacheManager: Test file exists: $exists');
      
      // Clean up
      await testFile.delete();
      print('CacheManager: Test completed successfully');
    } catch (e) {
      print('CacheManager: Test failed: $e');
    }
  }

  /// Clears the entire manga cache directory.
  Future<void> clearAllCache() async {
    final cacheDir = await getMainCacheDirectory();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
      // Recreate the directory for future use
      await cacheDir.create(recursive: true);
    }
  }

  /// Clears the cache (alias for clearAllCache for consistency with settings UI)
  Future<void> clearCache() async {
    await clearAllCache();
  }

  /// Clears cache for a specific manga.
  Future<void> clearMangaCache(String mangaTitle) async {
    try {
      final mangaDir = Directory('${(await getChaptersCacheDirectory()).path}/$mangaTitle');
      if (await mangaDir.exists()) {
        await mangaDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing manga cache: $e');
    }
  }

  /// Clears cache for a specific chapter.
  Future<void> clearChapterCache(String mangaTitle, String chapterId) async {
    try {
      final chapterDir = Directory('${(await getMangaCacheDirectory(mangaTitle)).path}/$chapterId');
      if (await chapterDir.exists()) {
        await chapterDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing chapter cache: $e');
    }
  }

  /// Helper method to calculate directory size recursively.
  int _getTotalSizeOfDirectory(Directory dir) {
    int totalSize = 0;
    try {
      if (dir.existsSync()) {
        List<FileSystemEntity> fileList = dir.listSync(recursive: true, followLinks: false);
        for (var file in fileList) {
          if (file is File) {
            totalSize += file.lengthSync();
          }
        }
      }
    } catch (e) {
      print('Error calculating cache size: $e');
    }
    return totalSize;
  }

  /// Gets the path string for the main cache directory.
  /// Useful for debugging or displaying paths in the UI.
  Future<String> getCacheDirectoryPath() async {
    final cacheDir = await getMainCacheDirectory();
    return cacheDir.path;
  }

  /// Verifies that the cache directory is properly hidden from the media scanner.
  /// On Android, directories starting with '.' are automatically hidden.
  bool isCacheDirectoryHidden() => _cacheDirectoryName.startsWith('.');

  /// Creates a .nomedia file in the cache directory to prevent media scanning
  Future<void> _createNomediaFile(Directory cacheDir) async {
    try {
      final nomediaFile = File('${cacheDir.path}/.nomedia');
      if (!await nomediaFile.exists()) {
        await nomediaFile.writeAsString('');
        print('CacheManager: Created .nomedia file to hide from gallery');
      }
    } catch (e) {
      print('CacheManager: Failed to create .nomedia file: $e');
    }
  }

  /// Ensures .nomedia file exists in the cache directory
  Future<void> _ensureNomediaFile(Directory cacheDir) async {
    try {
      final nomediaFile = File('${cacheDir.path}/.nomedia');
      if (!await nomediaFile.exists()) {
        await nomediaFile.writeAsString('');
        print('CacheManager: Created missing .nomedia file');
      }
    } catch (e) {
      print('CacheManager: Failed to ensure .nomedia file: $e');
    }
  }
}
