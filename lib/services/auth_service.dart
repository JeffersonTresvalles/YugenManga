import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Enhanced auth service with profile picture support and session management.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _profilePictureKey = 'user_profile_picture_url';

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserCredential> signInWithGoogle() async {
    // Force account selection with scopes and prompt
    final googleUser = await GoogleSignIn(
      scopes: ['email'],
    ).signIn();
    
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Sign-in cancelled. Feel free to try again whenever you\'re ready!',
      );
    }

    final googleAuth = await googleUser.authentication;
    if (googleAuth.idToken == null && googleAuth.accessToken == null) {
      throw FirebaseAuthException(
        code: 'ERROR_MISSING_GOOGLE_AUTH_TOKEN',
        message: 'Missing Google authentication token.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    
    // Fetch and cache profile data after successful sign-in
    await _fetchAndCacheUserProfile(userCredential.user);
    
    return userCredential;
  }

  /// Fetches the user's profile picture URL from Firebase Auth and caches it locally.
  /// Called immediately after successful Google Sign-In.
  Future<void> fetchAndCacheProfilePicture() async {
    await _fetchAndCacheUserProfile(_auth.currentUser);
  }

  /// Internal method to fetch and cache user profile data
  Future<void> _fetchAndCacheUserProfile(User? user) async {
    try {
      if (user == null) {
        print('AuthService: No user found');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      
      // Cache profile picture URL
      final photoUrl = user.photoURL;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await prefs.setString(_profilePictureKey, photoUrl);
        print('AuthService: Profile picture cached successfully');
      } else {
        print('AuthService: No profile picture URL available');
      }
      
      // Cache display name
      const displayNameKey = 'user_display_name';
      final displayName = user.displayName ?? 'Manga Reader';
      await prefs.setString(displayNameKey, displayName);
      print('AuthService: Display name cached: $displayName');
      
      // Cache email
      const emailKey = 'user_email';
      final email = user.email;
      if (email != null) {
        await prefs.setString(emailKey, email);
        print('AuthService: Email cached: $email');
      }
      
    } catch (e) {
      print('AuthService: Failed to cache user profile: $e');
    }
  }

  /// Gets the cached user profile data
  Future<Map<String, String?>> getCachedUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'photoUrl': prefs.getString(_profilePictureKey),
        'displayName': prefs.getString('user_display_name') ?? 'Manga Reader',
        'email': prefs.getString('user_email'),
      };
    } catch (e) {
      return {
        'photoUrl': null,
        'displayName': 'Manga Reader',
        'email': null,
      };
    }
  }

  /// Retrieves the cached profile picture URL if it exists.
  Future<String?> getCachedProfilePicture() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_profilePictureKey);
    } catch (e) {
      return null;
    }
  }

  /// Saves a local profile picture and caches its path
  Future<String?> saveProfilePicture(File imageFile) async {
    try {
      // Get the app's documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${appDir.path}/profile_pictures');
      
      // Create the directory if it doesn't exist
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }
      
      // Generate a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_$timestamp.jpg';
      final localPath = '${profileDir.path}/$fileName';
      
      // Copy the image to the local directory
      await imageFile.copy(localPath);
      
      // Cache the local path
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_profilePictureKey, localPath);
      
      print('AuthService: Profile picture saved locally: $localPath');
      return localPath;
    } catch (e) {
      print('AuthService: Failed to save profile picture: $e');
      return null;
    }
  }

  /// Clears the cached profile picture on sign out.
  Future<void> clearProfilePictureCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profilePictureKey);
      await prefs.remove('user_display_name');
      await prefs.remove('user_email');
      print('AuthService: Profile data cleared');
    } catch (e) {
      print('AuthService: Failed to clear profile picture cache: $e');
    }
  }

  /// Test method to verify profile integration is working
  Future<void> testProfileIntegration() async {
    try {
      print('AuthService: Testing profile integration...');
      
      final user = _auth.currentUser;
      if (user != null) {
        print('AuthService: Current user: ${user.displayName ?? user.email}');
        print('AuthService: User photoURL: ${user.photoURL}');
      } else {
        print('AuthService: No user currently signed in');
      }
      
      final cachedUrl = await getCachedProfilePicture();
      print('AuthService: Cached profile picture URL: $cachedUrl');
      
      print('AuthService: Profile integration test completed');
    } catch (e) {
      print('AuthService: Profile integration test failed: $e');
    }
  }

  Future<void> signOut() async {
    await clearProfilePictureCache();
    await _auth.signOut();
  }
}
