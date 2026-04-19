# YugenManga Login Redesign - Architecture & Flow

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER INTERFACE LAYER                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                 LoginScreen Widget                           │  │
│  │  ─────────────────────────────────────────────────────────  │  │
│  │                                                              │  │
│  │  📦 UI Components:                                           │  │
│  │   ├─ Glassmorphism Card (BackdropFilter)                    │  │
│  │   ├─ Animated Logo (Fade + Slide)                           │  │
│  │   ├─ Enhanced TextFields (Email, Password)                  │  │
│  │   ├─ Sign In Button                                         │  │
│  │   └─ Google Sign In Button (Integrated)                     │  │
│  │                                                              │  │
│  │  🎬 Animations:                                              │  │
│  │   ├─ Logo Fade In (0-840ms)                                │  │
│  │   └─ Logo Slide Up (0-1200ms)                              │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              ↓                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │            Input Handlers & Validators                       │  │
│  │  ─────────────────────────────────────────────────────────  │  │
│  │  _validateEmail()  → Regex validation                        │  │
│  │  _validatePassword() → Min 6 chars                           │  │
│  │  _submit()  → Auth method select                             │  │
│  │  _signInWithGoogle() → Google flow + profile fetch           │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                   SERVICES LAYER (Business Logic)                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────┐    ┌──────────────────────┐              │
│  │   AuthService        │    │  CacheManagerService │              │
│  │  ──────────────────  │    │  ──────────────────  │              │
│  │                      │    │                      │              │
│  │ • signInWithGoogle() │    │ • getChapter Dir()   │              │
│  │ • signUpEmail()      │    │ • getMangaDir()      │              │
│  │ • fetchProfile()     │    │ • getCacheSize()     │              │
│  │ • cacheProfilePic()  │    │ • clearAllCache()    │              │
│  │ • getProfilePic()    │    │ • clearMangaCache()  │              │
│  │ • clearCache()       │    │ • clearChapterCache()│              │
│  │ • signOut()          │    │ • hidden cache mgmt  │              │
│  │                      │    │                      │              │
│  └──────────────────────┘    └──────────────────────┘              │
│          ↓                            ↓                             │
│  ┌──────────────────┐      ┌──────────────────┐                    │
│  │  Firebase Auth   │      │  Shared Prefs    │                    │
│  │  (User object)   │      │  (Profile URL)   │                    │
│  └──────────────────┘      └──────────────────┘                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                      DATA STORAGE LAYER                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Firebase (Cloud)           Local Storage (Device)                  │
│  ─────────────────           ──────────────────────                 │
│  ┌──────────────┐          ┌──────────────────────┐                │
│  │ User Auth    │          │ SharedPreferences    │                │
│  │ • User ID    │  ←──────→ │ • profile_pic_url    │                │
│  │ • Email      │          │ • (other prefs)      │                │
│  │ • PhotoURL   │          └──────────────────────┘                │
│  │ • Display    │                                                  │
│  │   Name       │          ┌──────────────────────┐                │
│  └──────────────┘          │ File System          │                │
│                            │ .manga_cache/        │                │
│                            │ ├─ chapters/         │                │
│                            │ │  ├─ MangaTitle1/   │                │
│                            │ │  │  ├─ chapter_01/ │                │
│                            │ │  │  │  ├─ page_1.jpg│               │
│                            │ │  │  │  └─ page_2.jpg│               │
│                            │ │  │  └─ chapter_02/ │                │
│                            │ │  └─ MangaTitle2/   │                │
│                            │ └─ images/           │                │
│                            │    ├─ cover_1.jpg    │                │
│                            │    └─ thumb_1.jpg    │                │
│                            └──────────────────────┘                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Authentication Flow

```
START: User Opens App
   │
   ├─ LoginScreen() appears
   │  ├─ AnimationController initialized
   │  ├─ Logo animations setup
   │  └─ Mount state → animations start
   │
   │  (Logo fades in & slides up for 1.2s)
   │
   ├─ User sees login form
   │
   ├─ Option A: Email/Password Login
   │  │
   │  ├─ User enters email & password
   │  ├─ Validation: _validateEmail(), _validatePassword()
   │  ├─ User taps "Sign In"
   │  ├─ _submit() called
   │  ├─ AuthService.signInWithEmailAndPassword()
   │  ├─ Firebase processes request
   │  ├─ On success: NavigateTo(HomeScreen)
   │  └─ Profile picture NOT fetched (not Google auth)
   │
   ├─ Option B: Google Sign-In ⭐ (New Flow)
   │  │
   │  ├─ User taps "Continue with Google" button
   │  ├─ _signInWithGoogle() called
   │  ├─ GoogleSignIn().signIn()
   │  │  └─ Launches Google auth dialog
   │  │
   │  ├─ User selects Google account
   │  │
   │  ├─ GoogleAuth returns credentials
   │  ├─ AuthService.signInWithGoogle()
   │  ├─ Firebase processes Google credential
   │  │
   │  ├─ On success: ✨ NEW STEP ✨
   │  │  │
   │  │  ├─ user.photoURL available in Firebase User
   │  │  ├─ AuthService.fetchAndCacheProfilePicture()
   │  │  │  │
   │  │  │  ├─ Get photoURL from user object
   │  │  │  ├─ SharedPreferences.setString('user_profile_picture_url', url)
   │  │  │  ├─ Cache succeeds → Silent (non-blocking)
   │  │  │  └─ Cache fails → Logged silently
   │  │  │
   │  │  └─ Navigate to HomeScreen
   │  │
   │  └─ Profile picture now available via:
   │     └─ AuthService.getCachedProfilePicture()
   │
   └─ HomeScreen loads
      └─ Profile picture can be displayed immediately
         (no network request needed)

END: User authenticated & profile cached
```

---

## 📥 Download & Cache Flow

```
HomeScreen
   │
   ├─ User browses manga
   │
   ├─ User selects chapter to read
   │
   ├─ Check if chapter cached
   │  │
   │  ├─ If cached: Load from .manga_cache/ ✨ (Offline ready)
   │  │
   │  └─ If not cached: Download
   │     │
   │     ├─ Download chapter pages from API
   │     │
   │     ├─ Create cache directory structure:
   │     │  │
   │     │  └─ CacheManagerService.getChapterCacheDirectory()
   │     │     │
   │     │     ├─ Check Documents directory exists
   │     │     ├─ Create .manga_cache/ (hidden from media scanner)
   │     │     ├─ Create chapters/ subfolder
   │     │     ├─ Create MangaTitle/ subfolder
   │     │     ├─ Create ChapterId/ subfolder
   │     │     │
   │     │     └─ Return: /Documents/.manga_cache/chapters/MangaTitle/ChapterId/
   │     │
   │     ├─ Save pages to cache:
   │     │  │
   │     │  for each page:
   │     │    ├─ File(path/page_001.jpg).writeAsBytes(data)
   │     │    ├─ File(path/page_002.jpg).writeAsBytes(data)
   │     │    └─ ... repeat for all pages
   │     │
   │     └─ Mark as cached in database
   │
   ├─ Display chapter from cache in ReaderScreen
   │
   ├─ Cache directory structure:
   │  │
   │  └─ .manga_cache/
   │     ├─ chapters/
   │     │  ├─ Manga Title 1/
   │     │  │  ├─ chapter_001/
   │     │  │  │  ├─ page_001.jpg ← Hidden from Gallery
   │     │  │  │  └─ page_002.jpg ← Hidden from Gallery
   │     │  │  └─ chapter_002/
   │     │  │     └─ ...
   │     │  │
   │     │  └─ Manga Title 2/
   │     │     └─ ...
   │     │
   │     └─ images/
   │        ├─ cover_1.jpg
   │        └─ thumb_1.jpg
   │
   └─ Android Gallery App
      │
      ├─ Media Scanner runs
      │
      ├─ Scans /Documents/ directory
      │
      ├─ Finds .manga_cache/ (starts with dot)
      │
      ├─ IGNORES .manga_cache/ ✨ (Hidden!)
      │
      └─ Result: No manga images in Gallery/Photos app
```

---

## 🎬 Animation Lifecycle

```
Class initialization
   │
   ├─ initState()
   │  │
   │  ├─ _setupAnimations()
   │  │  │
   │  │  ├─ Create AnimationController
   │  │  │  ├─ Duration: 1200ms
   │  │  │  ├─ VSyncProvider: SingleTickerProviderStateMixin
   │  │  │  └─ Status: initialized (not running)
   │  │  │
   │  │  ├─ Create Fade Animation
   │  │  │  ├─ Begin: 0.0 (invisible)
   │  │  │  ├─ End: 1.0 (fully visible)
   │  │  │  ├─ Curve: Linear with Interval(0.0, 0.7)
   │  │  │  │  └─ Only animates for first 840ms of 1200ms
   │  │  │  └─ Applies to: Logo text
   │  │  │
   │  │  ├─ Create Slide Animation
   │  │  │  ├─ Begin: Offset(0, 0.3) (30% down)
   │  │  │  ├─ End: Offset.zero (centered)
   │  │  │  ├─ Curve: EaseOut for smooth deceleration
   │  │  │  │  └─ Animates entire 1200ms duration
   │  │  │  └─ Applies to: Logo text & subtitle
   │  │  │
   │  │  └─ controller.forward() ← START ANIMATIONS
   │  │     │
   │  │     └─ Triggers frame-by-frame updates
   │  │
   │  └─ Widget tree builds with animation references
   │
   ├─ Frame 0ms (Start)
   │  ├─ Logo opacity: 0% (invisible)
   │  ├─ Logo offset: 0.3 (30% below center)
   │  └─ Rendering: Not visible
   │
   ├─ Frame 600ms (Midway)
   │  ├─ Logo opacity: 100% (fully visible - fade finished at 840ms)
   │  ├─ Logo offset: ~0.15 (15% below center)
   │  └─ Rendering: Logo visible, moving up
   │
   ├─ Frame 840ms (Fade Complete)
   │  ├─ Logo opacity: 100% (stays 100%)
   │  ├─ Logo offset: ~0.05 (near center)
   │  └─ Rendering: Logo fully visible, almost in place
   │
   ├─ Frame 1200ms (Complete)
   │  ├─ Logo opacity: 100% (fully visible)
   │  ├─ Logo offset: 0 (centered perfectly)
   │  └─ Rendering: Logo in final position
   │
   └─ dispose()
      │
      ├─ AnimationController.dispose()
      │
      └─ Resources freed
```

---

## 📊 Data Flow Diagram

```
User Input
    │
    ├─ Tap Email Field
    │  └─ Focus listener → Border color changes
    │
    ├─ Type Email
    │  └─ onChanged() → Haptic feedback
    │
    ├─ Tap Password Field
    │  └─ Focus listener → Border color changes
    │
    ├─ Type Password
    │  └─ onChanged() → Haptic feedback
    │
    ├─ Tap Sign In (Email/Password)
    │  │
    │  └─ _submit()
    │     ├─ Validate email (regex)
    │     ├─ Validate password (min 6 chars)
    │     ├─ Call AuthService.signInWithEmailAndPassword()
    │     └─ On success: Navigate away
    │
    └─ Tap Continue with Google
       │
       └─ _signInWithGoogle()
          │
          ├─ GoogleSignIn().signIn()
          │  └─ System Google auth dialog
          │
          ├─ Get googleAuth credentials
          │
          ├─ AuthService.signInWithGoogle()
          │  └─ Firebase credential auth
          │
          ├─ AuthService.fetchAndCacheProfilePicture() ⭐
          │  │
          │  ├─ Get user.photoURL
          │  │
          │  └─ SharedPreferences.setString()
          │     └─ Cache 'user_profile_picture_url'
          │
          └─ Navigate away

Profile Picture Access (Later)
    │
    └─ HomeScreen builds
       │
       ├─ UserAvatar widget initializes
       │
       ├─ AuthService.getCachedProfilePicture()
       │  │
       │  └─ SharedPreferences.getString()
       │     └─ Returns cached URL instantly
       │
       └─ Image.network(cachedUrl)
          └─ Display: User's Google profile picture
```

---

## 🏗️ Class Hierarchy

```
StatefulWidget
└─ LoginScreen
   │
   └─ State<LoginScreen>
      └─ _LoginScreenState (SingleTickerProviderStateMixin)
         │
         ├─ Properties:
         │  ├─ AnimationController _logoAnimController
         │  ├─ Animation<double> _logoFadeAnimation
         │  ├─ Animation<Offset> _logoSlideAnimation
         │  ├─ TextEditingController _emailController
         │  ├─ TextEditingController _passwordController
         │  └─ Form _formKey
         │
         ├─ Lifecycle:
         │  ├─ initState() → _setupAnimations()
         │  ├─ build() → Scaffold + Stack + SingleChildScrollView
         │  └─ dispose() → Clean up controllers
         │
         ├─ Methods:
         │  ├─ _setupAnimations() → Create fade & slide
         │  ├─ _validateEmail() → Regex check
         │  ├─ _validatePassword() → Min 6 chars
         │  ├─ _submit() → Auth method dispatch
         │  ├─ _signInWithGoogle() → Google + profile fetch
         │  ├─ _toggleMode() → Login/Register switch
         │  ├─ _sendPasswordReset() → Email reset
         │  └─ Widget builders:
         │     ├─ _buildGlassmorphismCard()
         │     ├─ _buildAnimatedTextField()
         │     └─ _buildGoogleButton()
         │
         └─ Constants:
            ├─ _oledBlack = #000000
            ├─ _deepPurple = #1C0A4A
            └─ _accentPurple = #8E8FFA
```

---

## 🔌 Service Layer Interface

```
AuthService (Singleton)
├─ Properties:
│  ├─ FirebaseAuth _auth
│  └─ static const _profilePictureKey = 'user_profile_picture_url'
│
├─ Auth Methods:
│  ├─ signInWithEmailAndPassword({email, password})
│  ├─ signUpWithEmailAndPassword({email, password})
│  ├─ sendPasswordResetEmail({email})
│  └─ signInWithGoogle()
│
├─ Profile Methods (NEW):
│  ├─ fetchAndCacheProfilePicture() → Void
│  ├─ getCachedProfilePicture() → String?
│  └─ clearProfilePictureCache() → Void
│
├─ Session Methods:
│  ├─ authStateChanges() → Stream<User?>
│  ├─ currentUser → User?
│  └─ signOut() → Void (+ profile cleanup)
│
└─ Usage:
   ├─ await AuthService.instance.signInWithGoogle()
   ├─ await AuthService.instance.fetchAndCacheProfilePicture()
   └─ final url = await AuthService.instance.getCachedProfilePicture()


CacheManagerService (Singleton)
├─ Constants:
│  ├─ _cacheDirectoryName = '.manga_cache'
│  ├─ _chaptersCacheName = 'chapters'
│  └─ _imagesCacheName = 'images'
│
├─ Directory Methods:
│  ├─ getMainCacheDirectory() → Directory
│  ├─ getChaptersCacheDirectory() → Directory
│  ├─ getImagesCacheDirectory() → Directory
│  ├─ getMangaCacheDirectory(mangaTitle) → Directory
│  └─ getChapterCacheDirectory(mangaTitle, chapterId) → Directory
│
├─ Size Methods:
│  ├─ getCacheSizeInBytes() → int
│  ├─ getCacheSizeInMB() → double
│  └─ _getTotalSizeOfDirectory() → int (private)
│
├─ Clearing Methods:
│  ├─ clearAllCache() → Void
│  ├─ clearMangaCache(mangaTitle) → Void
│  └─ clearChapterCache(mangaTitle, chapterId) → Void
│
├─ Utility Methods:
│  ├─ getCacheDirectoryPath() → String
│  └─ isCacheDirectoryHidden() → bool
│
└─ Usage:
   ├─ final chapterDir = await CacheManagerService.instance
   │                         .getChapterCacheDirectory('One Piece', 'ch_001')
   ├─ final sizeMB = await CacheManagerService.instance.getCacheSizeInMB()
   └─ await CacheManagerService.instance.clearAllCache()
```

---

## 💾 File Storage Layout

```
<App Documents Directory>          (from getApplicationDocumentsDirectory())
│
├─ other_app_files.db
├─ preferences.json
│
└─ .yugen_data/                    ← Hidden (starts with dot)
   │
   ├─ chapters/
   │  │
   │  ├─ One Piece/
   │  │  ├─ chapter_001/
   │  │  │  ├─ page_001.jpg        (1.2 MB)
   │  │  │  ├─ page_002.jpg        (1.1 MB)
   │  │  │  └─ ... (up to 50 pages)
   │  │  │
   │  │  ├─ chapter_002/
   │  │  │  └─ page_*.jpg
   │  │  │
   │  │  └─ chapter_003/
   │  │     └─ page_*.jpg
   │  │
   │  ├─ Naruto/
   │  │  ├─ chapter_100/
   │  │  ├─ chapter_101/
   │  │  └─ chapter_102/
   │  │
   │  └─ My Hero Academia/
   │     └─ ...
   │
   └─ images/
      ├─ one_piece_cover.jpg    (cached cover)
      ├─ naruto_thumb.jpg       (cached thumbnail)
      └─ ... (other cached images)

Total Size: Can grow to several GB (user controls via clearing)
Hidden: Yes (Android media scanner ignores)
Accessible: Yes (directly by app, via Files manager)
Visible in Gallery: No ✓
```

---

## 🧮 Size Calculation Example

```
Calculation Flow:
_getTotalSizeOfDirectory(Directory dir)
    │
    ├─ dir.listSync(recursive: true)
    │  └─ Lists all files in .manga_cache recursively
    │
    ├─ For each FileSystemEntity:
    │  │
    │  ├─ if it's a File:
    │  │  └─ totalSize += file.lengthSync()
    │  │
    │  └─ if it's a Directory:
    │     └─ Skip (handled by recursive: true)
    │
    └─ return totalSize

Example Files:
chapter_001/
├─ page_001.jpg → 1,234,567 bytes
├─ page_002.jpg → 1,345,678 bytes
├─ page_003.jpg → 1,123,456 bytes
└─ page_004.jpg → 1,234,567 bytes
                 ─────────────────
Total:           4,938,268 bytes ≈ 4.71 MB

After getCacheSizeInMB():
4,938,268 / (1024 * 1024) = 4.706 MB
```

---

## ✅ State Management Flow

```
LoginScreen State Changes:

1️⃣ Initial State:
   ├─ _isLoading = false
   ├─ _isRegistering = false
   ├─ _obscurePassword = true
   ├─ _authError = null
   └─ Animations: initialized, not running

2️⃣ User types email:
   ├─ _authError = null (if was set)
   └─ Haptic feedback triggered

3️⃣ User taps Google button:
   ├─ setState(() {
   │   _authError = null
   │   _isLoading = true  ← Disables button, shows spinner
   │ })

4️⃣ Google auth dialog appears:
   └─ (External activity, app paused)

5️⃣ User returns from Google:
   ├─ fetchAndCacheProfilePicture()
   ├─ setState(() {
   │   _isLoading = false  ← Re-enables button, hides spinner
   │ })
   └─ Navigation triggered (outside this widget)

6️⃣ Error case:
   ├─ setState(() {
   │   _authError = "error message"
   │   _isLoading = false
   │ })
   └─ Error shows in red box at top of form
```

---

## 🔐 Security Considerations

```
Profile Picture:
├─ Fetched from: Firebase User.photoURL
├─ Stored in: SharedPreferences (device-local)
├─ Encryption: Device-level (SharedPreferences handles)
├─ Cleared on: signOut()
└─ Network: Only URL, not image data (Firebase serves on demand)

Cache Files:
├─ Location: App-specific documents directory
├─ Permissions: Only app can access directly
├─ Visibility: Hidden from media scanner (.manga_cache name)
├─ Encryption: Not encrypted (user choice - can add)
└─ Risk: Unencrypted on disk (typical for apps, apps handle their own)

Authorization:
├─ Google Sign-In uses: OAuth 2.0
├─ Firebase Auth uses: Secure tokens (auto-managed)
├─ Session: Firebase handles token refresh
└─ Logout: clearProfilePictureCache() + signOut()
```

---

**Now ready to deploy! See [README_REDESIGN.md](README_REDESIGN.md) for next steps.**
