import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// A singleton helper that manages the app's local SQLite database.
///
/// Provides CRUD operations for two tables:
/// - `downloads` — chapters saved to device storage for offline reading.
/// - `favorites`  — manga titles the user has bookmarked.
///
/// The singleton pattern ensures that only one [Database] connection is ever
/// open at a time, preventing concurrency issues and redundant file handles.
class DatabaseHelper {
  /// The single shared instance returned by the factory constructor.
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  /// Cached database connection. `null` until the first access.
  static Database? _database;

  /// Returns the shared [DatabaseHelper] instance.
  factory DatabaseHelper() => _instance;

  /// Private constructor that prevents external instantiation.
  DatabaseHelper._internal();

  // ── Database Initialisation ───────────────────────────────────────────────

  /// Lazily opens (or creates) the database and caches the connection.
  ///
  /// Subsequent calls return the already-open [Database] immediately,
  /// avoiding repeated disk I/O.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Opens the SQLite file at the platform's default databases path.
  ///
  /// **Schema version history:**
  /// - v1 — `downloads` table created.
  /// - v2 — `favorites` table added.
  /// - v3 — `coverPath` and `genre` columns added to `downloads`.
  ///
  /// The file is named `manga_v4.db`; the `v4` suffix was introduced to force
  /// a clean file when the schema changed incompatibly during development.
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'manga_v4.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        // Create the downloads table for offline chapter storage.
        // `id` is the MangaDex chapter UUID used as the unique key.
        await db.execute(
          'CREATE TABLE downloads(id TEXT PRIMARY KEY, mangaTitle TEXT, chapterNum TEXT, localPath TEXT, coverPath TEXT, genre TEXT)',
        );
        // Create the favorites table for bookmarked manga.
        await db.execute(
          'CREATE TABLE favorites(id TEXT PRIMARY KEY, title TEXT, thumbnail TEXT)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migrations are applied incrementally so a database at any earlier
        // version reaches the current schema correctly.
        if (oldVersion < 2) {
          // v1 → v2: Add the favorites table for newly introduced bookmarking.
          await db.execute(
              'CREATE TABLE IF NOT EXISTS favorites(id TEXT PRIMARY KEY, title TEXT, thumbnail TEXT)');
        }
        if (oldVersion < 3) {
          // v2 → v3: Extend downloads with cover image path and genre label.
          // The try/catch guards against the rare case where the columns were
          // added manually or a migration ran twice.
          try {
            await db.execute('ALTER TABLE downloads ADD COLUMN coverPath TEXT');
            await db.execute('ALTER TABLE downloads ADD COLUMN genre TEXT');
          } catch (e) {
            debugPrint("Columns might already exist: $e");
          }
        }
      },
    );
  }

  // ── Downloads ─────────────────────────────────────────────────────────────

  /// Returns one row per manga title, with a `chapterCount` column indicating
  /// how many chapters have been downloaded for that title.
  ///
  /// Results are sorted alphabetically by `mangaTitle` so the library screen
  /// can render them without additional sorting.
  ///
  /// Returns an empty list on any database error.
  Future<List<Map<String, dynamic>>> getDownloadsGroupedByManga() async {
    try {
      final db = await database;
      return await db.rawQuery('''
        SELECT *, COUNT(id) as chapterCount 
        FROM downloads 
        GROUP BY mangaTitle 
        ORDER BY mangaTitle ASC
      ''');
    } catch (e) {
      debugPrint("❌ GROUPED QUERY ERROR: $e");
      return [];
    }
  }

  /// Returns all downloaded chapters that belong to the manga with the given
  /// [title], ordered numerically by chapter number (ascending).
  ///
  /// `CAST(chapterNum AS INTEGER)` ensures `"10"` sorts after `"9"` rather
  /// than before it (which a plain lexicographic sort would produce).
  ///
  /// Returns an empty list on any database error.
  Future<List<Map<String, dynamic>>> getChaptersByManga(String title) async {
    try {
      final db = await database;
      return await db.query(
        'downloads',
        where: 'mangaTitle = ?',
        whereArgs: [title],
        orderBy: 'CAST(chapterNum AS INTEGER) ASC',
      );
    } catch (e) {
      debugPrint("❌ GET CHAPTERS ERROR: $e");
      return [];
    }
  }

  /// Inserts or replaces a chapter record in the `downloads` table.
  ///
  /// [download] must contain at minimum: `id`, `mangaTitle`, `chapterNum`,
  /// and `localPath`. The `coverPath` and `genre` fields are optional.
  ///
  /// [ConflictAlgorithm.replace] means re-downloading an existing chapter
  /// silently overwrites the old record rather than throwing an error.
  Future<void> insertDownload(Map<String, dynamic> download) async {
    try {
      final db = await database;
      await db.insert(
        'downloads',
        download,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint("❌ DB INSERT ERROR: $e");
    }
  }

  /// Deletes the downloaded chapter record identified by [id] (MangaDex chapter UUID).
  ///
  /// Note: this only removes the database row. The caller is responsible for
  /// deleting the corresponding files from local storage.
  Future<void> deleteDownload(String id) async {
    try {
      final db = await database;
      await db.delete('downloads', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint("❌ DB DELETE ERROR: $e");
    }
  }

  /// Returns every row in the `downloads` table as an unordered flat list.
  ///
  /// Prefer [getDownloadsGroupedByManga] or [getChaptersByManga] for UI
  /// display; this method is intended for bulk operations such as storage
  /// size calculations or export.
  ///
  /// Returns an empty list on any database error.
  Future<List<Map<String, dynamic>>> getDownloads() async {
    try {
      final db = await database;
      return await db.query('downloads');
    } catch (e) {
      return [];
    }
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  /// Adds [manga] to favorites if it is not already saved, or removes it if
  /// it is — effectively toggling the bookmarked state.
  ///
  /// [manga] must contain `id`, `title`, and `thumbnail` keys.
  /// Only those three fields are persisted; extra keys are ignored.
  Future<void> toggleFavorite(Map<String, dynamic> manga) async {
    final db = await database;
    // Check whether the manga is already in favorites before deciding the action.
    final List<Map<String, dynamic>> existing = await db.query(
      'favorites',
      where: 'id = ?',
      whereArgs: [manga['id']],
    );

    if (existing.isEmpty) {
      // Not yet a favorite — insert it.
      await db.insert('favorites', {
        'id': manga['id'],
        'title': manga['title'],
        'thumbnail': manga['thumbnail'],
      });
    } else {
      // Already a favorite — remove it.
      await db.delete('favorites', where: 'id = ?', whereArgs: [manga['id']]);
    }
  }

  /// Returns `true` if the manga identified by [id] is saved in favorites.
  Future<bool> isFavorite(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty;
  }

  /// Updates the `genre` field for every downloaded chapter that belongs to
  /// the manga identified by [mangaTitle].
  ///
  /// Genre data is fetched separately from chapter data (see `ApiService`),
  /// so this bulk update is called after the genre is resolved to back-fill
  /// all existing rows at once.
  Future<void> updateGenreByMangaTitle(String mangaTitle, String genre) async {
    try {
      final db = await database;
      await db.update(
        'downloads',
        {'genre': genre},
        where: 'mangaTitle = ?',
        whereArgs: [mangaTitle],
      );
    } catch (e) {
      debugPrint("❌ UPDATE GENRE ERROR: $e");
    }
  }

  /// Returns all favorite manga rows, ordered by insertion time (newest first).
  ///
  /// `rowid DESC` relies on SQLite's implicit auto-incrementing row ID, which
  /// reflects insertion order without requiring a dedicated timestamp column.
  ///
  /// Returns an empty list on any database error.
  Future<List<Map<String, dynamic>>> getFavorites() async {
    try {
      final db = await database;
      return await db.query('favorites', orderBy: 'rowid DESC');
    } catch (e) {
      return [];
    }
  }
}
