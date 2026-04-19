import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// A singleton helper that manages the app's local SQLite database.
///
/// Provides CRUD operations for two tables:
/// - `downloads` — chapters saved to device storage for offline reading.
/// - `favorites`  — manga titles the user has bookmarked.
///
/// Rows are scoped by Firebase [userId] (1 user : many favorites/downloads).
/// Call [setActiveUserId] when the signed-in user changes, before any DB use.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  static Database? _database;

  /// Firebase Auth UID for the current session. Set from [setActiveUserId].
  String? _activeUserId;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  /// Binds all queries and writes to this Firebase user. Pass `null` when logged out.
  void setActiveUserId(String? uid) {
    _activeUserId = uid;
  }

  String _requireUserId() {
    final u = _activeUserId;
    if (u == null || u.isEmpty) {
      throw StateError(
        'DatabaseHelper.setActiveUserId must be called with a signed-in user uid.',
      );
    }
    return u;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'manga_v4.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE downloads(
  id TEXT NOT NULL,
  userId TEXT NOT NULL,
  mangaId TEXT,
  mangaTitle TEXT,
  chapterNum TEXT,
  localPath TEXT,
  coverPath TEXT,
  genre TEXT,
  PRIMARY KEY (userId, id)
)''');
        await db.execute('''
CREATE TABLE favorites(
  userId TEXT NOT NULL,
  id TEXT NOT NULL,
  title TEXT,
  thumbnail TEXT,
  PRIMARY KEY (userId, id)
)''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS favorites(id TEXT PRIMARY KEY, title TEXT, thumbnail TEXT)');
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE downloads ADD COLUMN coverPath TEXT');
            await db.execute('ALTER TABLE downloads ADD COLUMN genre TEXT');
          } catch (e) {
            debugPrint("Columns might already exist: $e");
          }
        }
        if (oldVersion < 4) {
          await _migrateToUserScopedTables(db);
        }
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE downloads ADD COLUMN mangaId TEXT');
          } catch (e) {
            debugPrint("Columns might already exist: $e");
          }
        }
      },
    );
  }

  /// v3 → v4: composite primary keys and `userId` on every row (legacy → `_legacy`).
  Future<void> _migrateToUserScopedTables(Database db) async {
    await db.execute('''
CREATE TABLE downloads_new(
  id TEXT NOT NULL,
  userId TEXT NOT NULL,
  mangaTitle TEXT,
  chapterNum TEXT,
  localPath TEXT,
  coverPath TEXT,
  genre TEXT,
  PRIMARY KEY (userId, id)
)''');
    await db.execute('''
INSERT INTO downloads_new (id, userId, mangaTitle, chapterNum, localPath, coverPath, genre)
SELECT id, '_legacy', mangaTitle, chapterNum, localPath, coverPath, genre FROM downloads
''');
    await db.execute('DROP TABLE downloads');
    await db.execute('ALTER TABLE downloads_new RENAME TO downloads');

    await db.execute('''
CREATE TABLE favorites_new(
  userId TEXT NOT NULL,
  id TEXT NOT NULL,
  title TEXT,
  thumbnail TEXT,
  PRIMARY KEY (userId, id)
)''');
    await db.execute('''
INSERT INTO favorites_new (userId, id, title, thumbnail)
SELECT '_legacy', id, title, thumbnail FROM favorites
''');
    await db.execute('DROP TABLE favorites');
    await db.execute('ALTER TABLE favorites_new RENAME TO favorites');
  }

  // ── Downloads ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDownloadsGroupedByManga() async {
    final uid = _requireUserId();
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT
          mangaId,
          mangaTitle,
          genre,
          MIN(coverPath) AS coverPath,
          MIN(localPath) AS localPath,
          COUNT(id) as chapterCount
        FROM downloads
        WHERE userId = ?
        GROUP BY mangaId, mangaTitle
        ORDER BY mangaTitle ASC
      ''', [uid]);
    } catch (e) {
      debugPrint("❌ GROUPED QUERY ERROR: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getChaptersByManga(String title, {String? mangaId}) async {
    final uid = _requireUserId();
    try {
      final db = await database;
      if (mangaId != null && mangaId.isNotEmpty) {
        return await db.query(
          'downloads',
          where: 'mangaId = ? AND userId = ?',
          whereArgs: [mangaId, uid],
          orderBy: 'CAST(chapterNum AS INTEGER) ASC',
        );
      }
      return await db.query(
        'downloads',
        where: 'mangaTitle = ? AND userId = ?',
        whereArgs: [title, uid],
        orderBy: 'CAST(chapterNum AS INTEGER) ASC',
      );
    } catch (e) {
      debugPrint("❌ GET CHAPTERS ERROR: $e");
      return [];
    }
  }

  Future<void> insertDownload(Map<String, dynamic> download) async {
    final uid = _requireUserId();
    try {
      final db = await database;
      final row = Map<String, dynamic>.from(download);
      row['userId'] = uid;
      await db.insert(
        'downloads',
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint("❌ DB INSERT ERROR: $e");
    }
  }

  Future<void> deleteDownload(String id) async {
    final uid = _requireUserId();
    try {
      final db = await database;
      await db.delete(
        'downloads',
        where: 'id = ? AND userId = ?',
        whereArgs: [id, uid],
      );
    } catch (e) {
      debugPrint("❌ DB DELETE ERROR: $e");
    }
  }

  Future<void> deleteDownloadsByMangaId(String mangaId) async {
    final uid = _requireUserId();
    try {
      final db = await database;
      await db.delete(
        'downloads',
        where: 'mangaId = ? AND userId = ?',
        whereArgs: [mangaId, uid],
      );
    } catch (e) {
      debugPrint("❌ DB DELETE BY MANGA ID ERROR: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getDownloads() async {
    final uid = _requireUserId();
    try {
      final db = await database;
      return await db.query('downloads', where: 'userId = ?', whereArgs: [uid]);
    } catch (e) {
      return [];
    }
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  Future<void> insertFavorite(Map<String, dynamic> favorite) async {
    final uid = _requireUserId();
    final db = await database;
    final row = Map<String, dynamic>.from(favorite);
    row['userId'] = uid; // Ensure userId is set
    await db.insert(
      'favorites',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFavorite(String mangaId) async {
    final uid = _requireUserId();
    final db = await database;
    await db.delete(
      'favorites',
      where: 'id = ? AND userId = ?',
      whereArgs: [mangaId, uid],
    );
  }

  // The original toggleFavorite is not used by the current DetailScreen,
  // but if it were, it would need to accept categoryId.
  // Keeping it for now, but it's effectively unused by the main flow.
  Future<void> toggleFavorite(Map<String, dynamic> manga, {String? categoryId}) async {
    final uid = _requireUserId();
    final db = await database;
    final isCurrentlyFavorite = await isFavorite(manga['id']);

    if (isCurrentlyFavorite) {
      await deleteFavorite(manga['id']);
    } else {
      await insertFavorite({
        'id': manga['id'],
        'title': manga['title'],
        'thumbnail': manga['thumbnail'],
        'categoryId': categoryId,
      });
    }

  }

  Future<bool> isFavorite(String id) async {
    final uid = _requireUserId();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      where: 'id = ? AND userId = ?',
      whereArgs: [id, uid],
    );
    return maps.isNotEmpty;
  }

  Future<void> updateGenreByMangaTitle(String mangaTitle, String genre) async {
    final uid = _requireUserId();
    try {
      final db = await database;
      await db.update(
        'downloads',
        {'genre': genre},
        where: 'mangaTitle = ? AND userId = ?',
        whereArgs: [mangaTitle, uid],
      );
    } catch (e) {
      debugPrint("❌ UPDATE GENRE ERROR: $e");
    }
  }

  Future<void> updateGenreByMangaId(String mangaId, String genre) async {
    final uid = _requireUserId();
    try {
      final db = await database;
      await db.update(
        'downloads',
        {'genre': genre},
        where: 'mangaId = ? AND userId = ?',
        whereArgs: [mangaId, uid],
      );
    } catch (e) {
      debugPrint("❌ UPDATE GENRE BY ID ERROR: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final uid = _requireUserId();
    try {
      final db = await database;
      return await db.query(
        'favorites',
        where: 'userId = ?',
        whereArgs: [uid],
        columns: ['id', 'title', 'thumbnail'],
        orderBy: 'rowid DESC',
      );
    } catch (e) {
      return [];
    }
  }
}
