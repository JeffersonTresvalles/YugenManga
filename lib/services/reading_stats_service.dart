import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/reading_stats.dart';

/// Service for managing reading statistics in Firestore.
class ReadingStatsService {
  static final ReadingStatsService _instance = ReadingStatsService._internal();

  factory ReadingStatsService() => _instance;

  ReadingStatsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the collection path for the current user
  String get _userStatsPath => 'users/${_auth.currentUser?.uid}/stats';

  /// Fetch reading statistics for the current user
  Future<ReadingStats?> getReadingStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final doc = await _firestore.collection(_userStatsPath).doc('overview').get();

      if (!doc.exists) {
        // Create initial stats document if it doesn't exist
        final newStats = ReadingStats(userId: userId);
        await _firestore
            .collection(_userStatsPath)
            .doc('overview')
            .set(newStats.toFirestore());
        return newStats;
      }

      return ReadingStats.fromFirestore(doc.data() ?? {});
    } catch (e) {
      print('Error fetching reading stats: $e');
      return null;
    }
  }

  /// Update reading time (add minutes to total)
  Future<void> addReadingTime(int minutes) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final statsDoc = _firestore.collection(_userStatsPath).doc('overview');
      final stats = await getReadingStats();

      if (stats == null) return;

      // Update total reading time
      final newTotalMinutes = stats.totalReadingTimeMinutes + minutes;

      // Update daily reading time
      final now = DateTime.now();
      final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final dailyMinutes = stats.dailyReadingMinutes[dateKey] ?? 0;

      final updated = stats.copyWith(
        totalReadingTimeMinutes: newTotalMinutes,
        dailyReadingMinutes: {
          ...stats.dailyReadingMinutes,
          dateKey: dailyMinutes + minutes,
        },
      );

      await statsDoc.set(updated.toFirestore());
    } catch (e) {
      print('Error adding reading time: $e');
    }
  }

  /// Increment chapters read count
  Future<void> incrementChaptersRead() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final statsDoc = _firestore.collection(_userStatsPath).doc('overview');
      final stats = await getReadingStats();

      if (stats == null) return;

      final updated = stats.copyWith(
        totalChaptersRead: stats.totalChaptersRead + 1,
      );

      await statsDoc.set(updated.toFirestore());
    } catch (e) {
      print('Error incrementing chapters: $e');
    }
  }

  /// Update manga library count
  Future<void> updateMangaInLibraryCount(int count) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final statsDoc = _firestore.collection(_userStatsPath).doc('overview');
      final stats = await getReadingStats();

      if (stats == null) return;

      final updated = stats.copyWith(
        totalMangaInLibrary: count,
      );

      await statsDoc.set(updated.toFirestore());
    } catch (e) {
      print('Error updating manga count: $e');
    }
  }

  /// Update most read manga
  Future<void> updateMostReadManga(String title, String mangaId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final statsDoc = _firestore.collection(_userStatsPath).doc('overview');
      final stats = await getReadingStats();

      if (stats == null) return;

      final updated = stats.copyWith(
        mostReadMangaTitle: title,
        mostReadMangaId: mangaId,
      );

      await statsDoc.set(updated.toFirestore());
    } catch (e) {
      print('Error updating most read manga: $e');
    }
  }

  /// Calculate reading streak based on daily reading history
  Future<void> updateReadingStreak() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final stats = await getReadingStats();
      if (stats == null) return;

      // Calculate streak from daily reading minutes
      int streak = 0;
      DateTime currentDate = DateTime.now();

      while (true) {
        final dateKey =
            '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
        if ((stats.dailyReadingMinutes[dateKey] ?? 0) > 0) {
          streak++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      final statsDoc = _firestore.collection(_userStatsPath).doc('overview');
      final updated = stats.copyWith(readingStreak: streak);

      await statsDoc.set(updated.toFirestore());
    } catch (e) {
      print('Error updating reading streak: $e');
    }
  }

  /// Get reading activity data for heatmap (last 365 days)
  Future<Map<String, int>> getReadingActivityHeatmap() async {
    try {
      final stats = await getReadingStats();
      if (stats == null) return {};

      return stats.dailyReadingMinutes;
    } catch (e) {
      print('Error getting reading activity: $e');
      return {};
    }
  }

  /// Reset all stats (useful for testing or user request)
  Future<void> resetAllStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final newStats = ReadingStats(userId: userId);
      await _firestore.collection(_userStatsPath).doc('overview').set(newStats.toFirestore());
    } catch (e) {
      print('Error resetting stats: $e');
    }
  }
}
