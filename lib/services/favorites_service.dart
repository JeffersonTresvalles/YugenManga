import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database_helper.dart';

/// Service for managing user library in Firestore.
class FavoritesService {
  static final FavoritesService _instance = FavoritesService._internal();

  factory FavoritesService() => _instance;

  FavoritesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the collection path for the current user
  String get _userLibraryPath => 'users/${_auth.currentUser?.uid}/library';

  /// Check if a manga is in library
  Future<bool> isFavorite(String mangaId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final doc = await _firestore.collection(_userLibraryPath).doc(mangaId).get();
      return doc.exists;
    } catch (e) {
      print('Error checking library status: $e');
      return false;
    }
  }

  /// Add manga to library
  Future<void> addToFavorites({
    required String mangaId,
    required String title,
    required String coverUrl,
    String? author,
    String? status,
    String? source,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore.collection(_userLibraryPath).doc(mangaId).set({
        'mangaId': mangaId,
        'title': title,
        'coverUrl': coverUrl,
        'author': author,
        'status': status,
        'source': source,
        'dateAdded': FieldValue.serverTimestamp(),
      });

      // Sync to local database
      await DatabaseHelper().insertFavorite({
        'id': mangaId,
        'title': title,
        'thumbnail': coverUrl,
        'userId': userId, // DatabaseHelper expects userId in the map
      });
    } catch (e) {
      print('Error adding to favorites: $e');
      throw e;
    }
  }

  /// Remove manga from library
  Future<void> removeFromFavorites(String mangaId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore.collection(_userLibraryPath).doc(mangaId).delete();

      // Sync to local database
      await DatabaseHelper().deleteFavorite(mangaId);
    } catch (e) {
      print('Error removing from library: $e');
      throw e;
    }
  }

  /// Toggle library status
  Future<bool> toggleFavorite({
    required String mangaId,
    required String title,
    required String coverUrl,
    String? author,
    String? status,
    String? source,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final isCurrentlyFavorite = await isFavorite(mangaId);

      if (isCurrentlyFavorite) {
        await removeFromFavorites(mangaId);
        return false; // Now not favorite
      } else {
        await addToFavorites(
          mangaId: mangaId,
          title: title,
          coverUrl: coverUrl,
          author: author,
          status: status,
          source: source,
        );
        return true; // Now favorite
      }
    } catch (e) {
      print('Error toggling library: $e');
      throw e;
    }
  }

  /// Get all library items for the current user as a stream
  Stream<List<Map<String, dynamic>>> getFavoritesStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection(_userLibraryPath)
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}