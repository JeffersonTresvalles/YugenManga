# Integration Guide - YugenManga Login Redesign

## Quick Start

### Files Modified/Created:

1. **[lib/screens/login_screen.dart](../lib/screens/login_screen.dart)** - Complete redesign with:
   - Glassmorphism effects
   - Animated logo
   - Enhanced text fields
   - Integrated Google button
   - Profile picture fetching

2. **[lib/services/auth_service.dart](../lib/services/auth_service.dart)** - Enhanced with:
   - Profile picture caching
   - Auto-fetch after Google Sign-In
   - Cache clearing on sign-out

3. **[lib/services/cache_manager_service.dart](../lib/services/cache_manager_service.dart)** - NEW:
   - Hidden manga cache directory management
   - Chapter/image organization
   - Cache size calculation
   - Progressive clearing

4. **[LOGIN_REDESIGN_GUIDE.md](../LOGIN_REDESIGN_GUIDE.md)** - Complete documentation

---

## Using the Cache Manager in Downloads

### Example 1: Save Downloaded Chapter Images

```dart
import 'package:my_first_app/services/cache_manager_service.dart';

Future<void> saveChapterImages(
  String mangaTitle,
  String chapterId,
  List<Uint8List> pageImages,
) async {
  try {
    final chapterDir = await CacheManagerService.instance
        .getChapterCacheDirectory(mangaTitle, chapterId);
    
    for (int i = 0; i < pageImages.length; i++) {
      final pageNum = (i + 1).toString().padLeft(3, '0');
      final pagePath = '${chapterDir.path}/page_$pageNum.jpg';
      
      final file = File(pagePath);
      await file.writeAsBytes(pageImages[i]);
      
      print('Saved: page_$pageNum.jpg');
    }
    
    print('Chapter saved successfully');
  } catch (e) {
    print('Error saving chapter: $e');
  }
}
```

### Example 2: Load Offline Chapter

```dart
Future<List<File>> loadOfflineChapter(
  String mangaTitle,
  String chapterId,
) async {
  try {
    final chapterDir = await CacheManagerService.instance
        .getChapterCacheDirectory(mangaTitle, chapterId);
    
    if (!await chapterDir.exists()) {
      return [];
    }
    
    final files = chapterDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
        .toList();
    
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  } catch (e) {
    print('Error loading offline chapter: $e');
    return [];
  }
}
```

### Example 3: Show Cache Size in Settings

```dart
Future<void> showCacheSize() async {
  final sizeInMB = await CacheManagerService.instance.getCacheSizeInMB();
  final formattedSize = sizeInMB.toStringAsFixed(2);
  
  print('Total cache size: $formattedSize MB');
  
  // Display in UI
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cache Size'),
      content: Text('Downloaded manga: $formattedSize MB'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: () {
            _clearCache();
            Navigator.pop(context);
          },
          child: const Text('Clear All', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

Future<void> _clearCache() async {
  await CacheManagerService.instance.clearAllCache();
  // Show confirmation
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Cache cleared')),
  );
}
```

### Example 4: Clear Specific Manga Cache

```dart
Future<void> deleteManga(String mangaTitle) async {
  try {
    await CacheManagerService.instance.clearMangaCache(mangaTitle);
    print('$mangaTitle deleted from cache');
  } catch (e) {
    print('Error deleting $mangaTitle: $e');
  }
}
```

---

## Using Profile Picture in Home Screen

### Example: Display Cached Profile Picture

```dart
import 'package:my_first_app/services/auth_service.dart';

class UserProfileWidget extends StatefulWidget {
  const UserProfileWidget({Key? key}) : super(key: key);

  @override
  State<UserProfileWidget> createState() => _UserProfileWidgetState();
}

class _UserProfileWidgetState extends State<UserProfileWidget> {
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    final url = await AuthService.instance.getCachedProfilePicture();
    if (mounted) {
      setState(() => _profilePictureUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_profilePictureUrl == null) {
      return const CircleAvatar(
        child: Icon(Icons.person),
      );
    }

    return CircleAvatar(
      backgroundImage: NetworkImage(_profilePictureUrl!),
    );
  }
}
```

---

## Migration from Old Downloads

If you already have downloaded manga in a different location, here's how to migrate:

```dart
import 'dart:io';
import 'package:my_first_app/services/cache_manager_service.dart';

Future<void> migrateLegacyDownloads(Directory oldDownloadDir) async {
  try {
    print('Starting migration...');
    
    // Get all manga folders from old location
    final mangaFolders = oldDownloadDir
        .listSync()
        .whereType<Directory>()
        .toList();
    
    for (final mangaFolder in mangaFolders) {
      final mangaTitle = mangaFolder.path.split('/').last;
      
      // Get all chapter folders
      final chapterFolders = mangaFolder
          .listSync()
          .whereType<Directory>()
          .toList();
      
      for (final chapterFolder in chapterFolders) {
        final chapterId = chapterFolder.path.split('/').last;
        
        // Get new chapter directory
        final newChapterDir = await CacheManagerService.instance
            .getChapterCacheDirectory(mangaTitle, chapterId);
        
        // Copy images
        final images = chapterFolder
            .listSync()
            .whereType<File>()
            .toList();
        
        for (final image in images) {
          final fileName = image.path.split('/').last;
          await image.copy('${newChapterDir.path}/$fileName');
        }
        
        print('Migrated: $mangaTitle / $chapterId');
      }
    }
    
    print('Migration complete!');
  } catch (e) {
    print('Migration error: $e');
  }
}
```

---

## Android Permissions

The app already has the necessary permissions. Verify in `android/app/AndroidManifest.xml`:

```xml
<!-- Storage permissions (already included if using documents directory) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

The `.manga_cache` directory doesn't require special scoped storage considerations since it's in the app's documents directory.

---

## Testing the Implementation

### Test 1: Verify Glassmorphism Renders
1. Run the app
2. Ensure the login card has a frosted glass appearance
3. Background gradient should be visible through the card

### Test 2: Verify Logo Animation
1. Watch the YugenManga logo on login screen
2. Should fade in and slide up smoothly over 1.2 seconds
3. Animation should trigger on screen load

### Test 3: Verify Profile Picture Caching
1. Login with Google account that has a profile picture
2. Check in SharedPreferences that `user_profile_picture_url` is saved
3. Sign out and sign in again - picture should load from cache

### Test 4: Verify Cache Directory
1. Download a chapter using the app
2. Use Android Studio's Device File Explorer
3. Navigate to: `data/data/com.example.my_first_app/app_documents/.manga_cache/`
4. Verify folder structure is created correctly

### Test 5: Verify Images Hidden from Gallery
1. Connect device via ADB
2. Open Gallery/Photos app
3. Verify no images from `.manga_cache` appear
4. Use Files app and navigate to Documents folder
5. Enable "Show Hidden Files" to see `.manga_cache`

---

## Troubleshooting

### Glassmorphism Not Showing
- **Issue**: Login card looks opaque instead of frosted glass
- **Solution**: Ensure background gradient is behind the card, check device supports ImageFilter

### Animation Not Playing
- **Issue**: Logo appears instantly without fade/slide
- **Solution**: Check AnimationController is properly initialized, verify vsync is correct

### Cache Directory Not Created
- **Issue**: `getChapterCacheDirectory()` throws error
- **Solution**: Ensure app has write permission, check device storage space

### Profile Picture Not Loading
- **Issue**: Profile picture URL not cached
- **Solution**: 
  - Verify Google Sign-In includes profile scope
  - Check user account has profile picture
  - Verify SharedPreferences is accessible

---

## Performance Tips

1. **Cache Size**: Periodically check and offer cache clearing in settings
2. **Lazy Loading**: Don't load all cached chapters at once
3. **Background Uploads**: Migrate old downloads in background task
4. **Compression**: Consider WebP format for smaller file sizes
5. **TTL**: Implement old cache deletion after 30 days

---

## Next Steps

1. ✅ Update login_screen.dart - DONE
2. ✅ Update auth_service.dart - DONE  
3. ✅ Create cache_manager_service.dart - DONE
4. ⏳ Integrate cache manager with download_service.dart
5. ⏳ Update home/profile screens to use cached profile picture
6. ⏳ Add cache management UI to settings screen
7. ⏳ Implement offline chapter viewing
8. ⏳ Add migration script for legacy downloads

---

**For detailed information, see: [LOGIN_REDESIGN_GUIDE.md](../LOGIN_REDESIGN_GUIDE.md)**
