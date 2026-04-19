# YugenManga Login Page Redesign - 'Manga-Noir' Aesthetic

## Overview
The YugenManga login page has been completely redesigned with a modern, sleek 'Manga-Noir' aesthetic featuring glassmorphism effects, subtle animations, and enhanced profile integration.

---

## 🎨 UI/UX Features Implemented

### 1. **Glassmorphism Login Card**
- **Effect**: Semi-transparent card with a glass-like blur effect using `BackdropFilter` and `ImageFilter.blur()`
- **Design**: 
  - 8% transparent white background with 10px blur radius
  - 15% transparent white border (1.5px width)
  - Dual-layer shadow for depth (purple shadows)
  - Rounded corners (24px radius) for modern appearance

**Key Implementation Details:**
```dart
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    ),
  ),
)
```

### 2. **Animated Logo & Title**
- **Animations**: 
  - Fade-in effect (0-1200ms)
  - Simultaneous slide-up animation (from offset 0.3 to 0)
  - Easing: Curved animation with 70% interval for fade, easeOut for slide
- **Visual Enhancement**:
  - Increased font size to 36px with 900 weight
  - Added subtle gradient underline in accent purple
  - Improved letter spacing (1.2) for premium feel

**Implementation:**
```dart
SlideTransition(
  position: _logoSlideAnimation,
  child: FadeTransition(
    opacity: _logoFadeAnimation,
    child: /* Logo content */
  ),
)
```

### 3. **Enhanced TextFields with Deep Purple Borders**
- **Default State**: 
  - Deep purple border (30% opacity) when disabled
  - Subtle 5% opacity white fill
  - Icons and labels in accent purple

- **Focused State**:
  - Deep purple border becomes vibrant accent purple
  - Border width increases from 1.2px to 2px
  - Label color adjusts for better contrast

- **Features**:
  - Custom suffix icons with proper spacing
  - Email validation with regex
  - Password strength validation (min 6 chars)
  - Haptic feedback on input changes

### 4. **Integrated Google Sign-In Button**
- **Design Philosophy**: Looks integrated rather than a standard block button
- **Visual Features**:
  - Gradient background (purple accent at 12% opacity fading to 5%)
  - Purple accent border (30% opacity, 1.2px)
  - Subtle shadow (purple accent at 10% opacity)
  - Custom "G" icon from Material Icons (`Icons.g_mobiledata`)
  - Text: "Continue with Google" with proper letter spacing

- **Interaction**:
  - Ripple effect on tap using `InkWell`
  - Proper disabled state when authentication is in progress
  - Haptic feedback integration

**Implementation:**
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    gradient: LinearGradient(
      colors: [
        _accentPurple.withValues(alpha: 0.12),
        _accentPurple.withValues(alpha: 0.05),
      ],
    ),
    border: Border.all(color: _accentPurple.withValues(alpha: 0.3)),
    boxShadow: [BoxShadow(color: _accentPurple.withValues(alpha: 0.1))],
  ),
)
```

---

## 🔐 Authentication & Profile Integration

### Enhanced AuthService (`auth_service.dart`)
Added three new methods to support profile picture management:

#### 1. **`fetchAndCacheProfilePicture()`**
- **Purpose**: Automatically called after successful Google Sign-In
- **Functionality**:
  - Retrieves the user's profile picture URL from Firebase Auth
  - Caches it in SharedPreferences for quick access
  - Runs silently without blocking authentication flow
- **Data Stored**: Key = `'user_profile_picture_url'`

#### 2. **`getCachedProfilePicture()`**
- **Returns**: Cached profile picture URL or null if not available
- **Use Case**: Display user profile picture in home screen or settings

#### 3. **`clearProfilePictureCache()`**
- **Purpose**: Clears cached data when user signs out
- **Integrates**: Automatically called in `signOut()` method

**Code Structure:**
```dart
Future<void> fetchAndCacheProfilePicture() async {
  final user = _auth.currentUser;
  final photoUrl = user?.photoURL;
  if (photoUrl != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile_picture_url', photoUrl);
  }
}
```

---

## 📁 Hidden Downloads Logic (`cache_manager_service.dart`)

### CacheManagerService - Complete Cache Management System

**Purpose**: Ensures all downloaded manga and chapters are stored in a hidden directory that the Android media scanner ignores.

#### Directory Structure:
```
<ApplicationDocumentsDirectory>/
├── .manga_cache/                    # Hidden from Gallery/Photos (starts with .)
│   ├── chapters/
│   │   ├── MangaTitle1/
│   │   │   ├── chapter_001/
│   │   │   ├── chapter_002/
│   │   │   └── ...
│   │   └── MangaTitle2/
│   │       └── ...
│   └── images/
│       └── (cached cover images, thumbnails, etc.)
```

#### Key Methods:

1. **`getMainCacheDirectory()`**
   - Returns: `<ApplicationDocumentsDirectory>/.manga_cache`
   - Auto-creates directory if it doesn't exist

2. **`getChaptersCacheDirectory()`**
   - Returns: Main cache + `/chapters` subdirectory
   - Used for storing chapter images

3. **`getImagesCacheDirectory()`**
   - Returns: Main cache + `/images` subdirectory
   - Used for thumbnails and cover images

4. **`getMangaCacheDirectory(String mangaTitle)`**
   - Returns: `.../.manga_cache/chapters/{mangaTitle}`
   - Creates manga-specific folders dynamically

5. **`getChapterCacheDirectory(String mangaTitle, String chapterId)`**
   - Returns: `.../.manga_cache/chapters/{mangaTitle}/{chapterId}`
   - Full path for individual chapter images

6. **`getCacheSizeInBytes()` / `getCacheSizeInMB()`**
   - Calculate total cache size
   - Useful for storage management UI

7. **`clearAllCache()`, `clearMangaCache()`, `clearChapterCache()`**
   - Progressive cache clearing options
   - Supports fine-grained cache management

#### Why `.manga_cache` is Hidden:
On Android, any file or directory name starting with a dot (`.`) is automatically ignored by the media scanner. This means:
- ✅ Images won't appear in Gallery or Photos apps
- ✅ Still accessible to the YugenManga app
- ✅ No need for special permissions
- ✅ Standard Android convention for private app data

**Usage Example:**
```dart
// Get directory for a specific chapter
final chapterDir = await CacheManagerService.instance
    .getChapterCacheDirectory('One Piece', 'ch_001');

// Save an image
final imagePath = '${chapterDir.path}/page_01.jpg';
await imageFile.copy(imagePath);

// Check cache size
final sizeMB = await CacheManagerService.instance.getCacheSizeInMB();
print('Cache size: ${sizeMB.toStringAsFixed(2)} MB');

// Clear old manga
await CacheManagerService.instance.clearMangaCache('Old Series');
```

---

## 🎯 Color Palette - 'Manga-Noir' Theme

```dart
const Color _oledBlack = Color(0xFF000000);      // Pure black for OLED efficiency
const Color _deepPurple = Color(0xFF1C0A4A);     // Dark purple accents
const Color _accentPurple = Color(0xFF8E8FFA);   // Vibrant purple highlights
```

### Color Usage:
- **OLED Black**: Background, prevents burning on OLED screens
- **Deep Purple**: Borders, shadows, gradient accents
- **Accent Purple**: Primary interactive elements, focus states, highlights

---

## 🚀 Integration Steps

### 1. Update Login Screen
The `login_screen.dart` now includes:
- ✅ Glassmorphism card design
- ✅ Animated logo with multiple effects
- ✅ Enhanced text fields with floating labels
- ✅ Integrated Google button
- ✅ Profile picture fetching on Google Sign-In

### 2. Update Authentication Service
The `auth_service.dart` now includes:
- ✅ Profile picture caching
- ✅ Auto-fetch after Google Sign-In
- ✅ Cache clearing on sign-out

### 3. Add Cache Management
New `cache_manager_service.dart` provides:
- ✅ Hidden directory management
- ✅ Organized chapter/image storage
- ✅ Cache size calculation
- ✅ Progressive clearing options

### 4. Delete Old Login Page (if exists)
If there was a `login_page.dart`, you can remove it as the functionality is now in `login_screen.dart`.

---

## 📱 Platform-Specific Considerations

### Android
- Hidden directory (`.manga_cache`) automatically excluded from media scanner
- No additional permission required
- Standard practice following Android conventions

### iOS
- Similar hidden directory approach
- Will be excluded from iCloud backup (app-specific documents)
- Requires iOS 11+

---

## 🎬 Animation Timeline

The logo animations are carefully sequenced:

```
1200ms total duration
│
├─ 0-840ms:   Fade in (0 → 1) - Linear interval
├─ 0-1200ms:  Slide up (0.3 offset → 0) - EaseOut curve
│
└─ Complete animation on load
```

---

## 🔄 Dependencies Used

- **`dart:ui`**: For `ImageFilter.blur()` - Glassmorphism effect
- **`firebase_auth`**: User authentication and profile data
- **`google_sign_in`**: Google authentication
- **`shared_preferences`**: Profile picture URL caching
- **`path_provider`**: Application documents directory access
- **`google_fonts`**: Nunito font family
- **`flutter/services`**: Haptic feedback

All dependencies already exist in `pubspec.yaml` ✅

---

## 📊 Performance Considerations

### Glassmorphism
- Uses `BackdropFilter` with 10px blur (optimized for performance)
- Avoid overusing due to GPU strain
- Works best with solid backgrounds

### Animations
- 1.2 second duration (smooth but responsive)
- Uses `SingleTickerProviderStateMixin` for efficiency
- Automatically disposed on widget destruction

### Cache Management
- Lazy directory creation (only when needed)
- Size calculation is recursive but cached in preferences
- Supports cancellation of long-running clears

---

## 🎨 Design System

### Spacing Scale
- Small: 8, 12, 14px
- Medium: 16, 18, 20px
- Large: 28, 40px

### Border Radius
- Small elements: 12-14px
- Cards: 24px
- Buttons: 14-16px

### Text Hierarchy
- Title: 36px, weight 900
- Subtitle: 15px, weight 500
- Labels: 13px, weight 600
- Body: 14px, weight 500

---

## ✨ Future Enhancements

1. **Biometric Login**: Add fingerprint/face ID for faster authentication
2. **Profile Picture Display**: Show cached profile picture in home screen
3. **Smart Cache**: Automatic cache cleanup based on age/size
4. **Download Indicators**: Show download progress with cache manager integration
5. **Offline Mode**: Leverage cache for offline manga viewing

---

## 🐛 Troubleshooting

### Profile Picture Not Showing
- Ensure Google Sign-In is properly configured
- Check SharedPreferences access permissions
- Verify Firebase user object has `photoURL`

### Cache Not Working
- Verify `path_provider` package is properly installed
- Check app has write permissions to documents directory
- Ensure directory creation completes before saving files

### Glassmorphism Looks Dull
- Verify device supports `ImageFilter.blur()`
- Check background gradient is visible
- Adjust alpha values if needed on low-end devices

---

## 📚 Additional Resources

- [Glassmorphism Design Trend](https://uxdesignagency.com/glassmorphism-design-trend/)
- [Flutter ImageFilter Documentation](https://api.flutter.dev/flutter/dart-ui/ImageFilter-class.html)
- [Android Media Scanner Behavior](https://developer.android.com/training/data-storage/shared/media)
- [Firebase Auth Best Practices](https://firebase.google.com/docs/auth/best-practices)

---

**Version**: 1.0  
**Last Updated**: April 2026  
**Design System**: Manga-Noir  
**Theme**: Dark Mode OLED-optimized
