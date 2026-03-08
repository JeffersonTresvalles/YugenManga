import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/manga.dart';

/// Manages the user's favorite manga list using [SharedPreferences] as a
/// lightweight persistence layer.
///
/// Favorites are serialized to a JSON string and stored under a single key.
/// This approach is suitable for small collections; for larger libraries,
/// consider migrating to the SQLite-backed [DatabaseHelper] instead.
///
/// ### Data format
/// The stored JSON mirrors the MangaDex API shape so that [Manga.fromJson]
/// can deserialize it without a separate DTO:
/// ```json
/// [
///   {
///     "id": "abc-123",
///     "attributes": {
///       "title": { "en": "Some Manga" },
///       "description": { "en": "A description." }
///     }
///   }
/// ]
/// ```
class FavoriteManager {
  /// [SharedPreferences] key under which the serialized favorites list is stored.
  static const String _key = 'favorite_mangas';

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Loads and deserializes the persisted favorites list.
  ///
  /// Returns an empty list when no favorites have been saved yet (i.e. the
  /// key is absent from [SharedPreferences]).
  Future<List<Manga>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_key);

    // No data stored yet — treat as an empty list rather than an error.
    if (data == null) return [];

    // Decode the raw JSON string and map each element through Manga.fromJson.
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => Manga.fromJson(json)).toList();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Toggles [manga]'s presence in the persisted favorites list.
  ///
  /// - If [manga] is **already** a favorite (matched by [Manga.id]), it is
  ///   removed.
  /// - If [manga] is **not** a favorite, it is appended to the list.
  ///
  /// The updated list is re-serialized and written back to [SharedPreferences]
  /// in a single atomic [SharedPreferences.setString] call, replacing the
  /// previous value entirely.
  ///
  /// Only [Manga.id], [Manga.title], and [Manga.description] are persisted.
  /// Fields such as `coverUrl` are intentionally omitted because they can be
  /// re-fetched from the API and would bloat the stored payload.
  Future<void> toggleFavorite(Manga manga) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await loadFavorites();

    // Locate the manga by ID (-1 means it is not currently a favorite).
    final index = favorites.indexWhere((m) => m.id == manga.id);

    if (index >= 0) {
      // Already a favorite — remove it.
      favorites.removeAt(index);
    } else {
      // Not yet a favorite — add it.
      favorites.add(manga);
    }

    // Re-serialize the updated list into the same JSON shape that
    // Manga.fromJson expects, so deserialization on the next load is seamless.
    final String encodedData = jsonEncode(
      favorites
          .map((m) => {
                'id': m.id,
                'attributes': {
                  'title': {'en': m.title},
                  'description': {'en': m.description}
                }
              })
          .toList(),
    );

    // Overwrite the previous value with the freshly serialized list.
    await prefs.setString(_key, encodedData);
  }
}
