import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing reading statistics for a user.
class ReadingStats {
  final String userId;
  final int totalReadingTimeMinutes; // Total reading time in minutes
  final int totalChaptersRead;
  final int totalMangaInLibrary;
  final int readingStreak; // Consecutive days
  final String mostReadMangaTitle;
  final String mostReadMangaId;
  final DateTime lastReadDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, int> dailyReadingMinutes; // Date -> minutes

  ReadingStats({
    required this.userId,
    this.totalReadingTimeMinutes = 0,
    this.totalChaptersRead = 0,
    this.totalMangaInLibrary = 0,
    this.readingStreak = 0,
    this.mostReadMangaTitle = '',
    this.mostReadMangaId = '',
    DateTime? lastReadDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, int>? dailyReadingMinutes,
  })  : lastReadDate = lastReadDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        dailyReadingMinutes = dailyReadingMinutes ?? {};

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'totalReadingTimeMinutes': totalReadingTimeMinutes,
      'totalChaptersRead': totalChaptersRead,
      'totalMangaInLibrary': totalMangaInLibrary,
      'readingStreak': readingStreak,
      'mostReadMangaTitle': mostReadMangaTitle,
      'mostReadMangaId': mostReadMangaId,
      'lastReadDate': lastReadDate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'dailyReadingMinutes': dailyReadingMinutes,
    };
  }

  /// Create from Firestore document
  factory ReadingStats.fromFirestore(Map<String, dynamic> data) {
    return ReadingStats(
      userId: data['userId'] ?? '',
      totalReadingTimeMinutes: data['totalReadingTimeMinutes'] ?? 0,
      totalChaptersRead: data['totalChaptersRead'] ?? 0,
      totalMangaInLibrary: data['totalMangaInLibrary'] ?? 0,
      readingStreak: data['readingStreak'] ?? 0,
      mostReadMangaTitle: data['mostReadMangaTitle'] ?? '',
      mostReadMangaId: (data['mostReadMangaId'] ?? '').toString(),
      lastReadDate: (data['lastReadDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dailyReadingMinutes:
          Map<String, int>.from(data['dailyReadingMinutes'] ?? {}),
    );
  }

  /// Calculate average reading time per chapter
  double getAverageReadingTimePerChapter() {
    if (totalChaptersRead == 0) return 0;
    return totalReadingTimeMinutes / totalChaptersRead;
  }

  /// Get reading hours
  int getReadingHours() => totalReadingTimeMinutes ~/ 60;

  /// Get remaining minutes after hours
  int getRemainingMinutes() => totalReadingTimeMinutes % 60;

  /// Create a copy with updated fields
  ReadingStats copyWith({
    int? totalReadingTimeMinutes,
    int? totalChaptersRead,
    int? totalMangaInLibrary,
    int? readingStreak,
    String? mostReadMangaTitle,
    String? mostReadMangaId,
    DateTime? lastReadDate,
    Map<String, int>? dailyReadingMinutes,
  }) {
    return ReadingStats(
      userId: userId,
      totalReadingTimeMinutes: totalReadingTimeMinutes ?? this.totalReadingTimeMinutes,
      totalChaptersRead: totalChaptersRead ?? this.totalChaptersRead,
      totalMangaInLibrary: totalMangaInLibrary ?? this.totalMangaInLibrary,
      readingStreak: readingStreak ?? this.readingStreak,
      mostReadMangaTitle: mostReadMangaTitle ?? this.mostReadMangaTitle,
      mostReadMangaId: mostReadMangaId ?? this.mostReadMangaId,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      dailyReadingMinutes: dailyReadingMinutes ?? this.dailyReadingMinutes,
    );
  }
}
