import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/manga.dart';

/// Handles all HTTP communication with the [MangaDex API v5](https://api.mangadex.org/docs/).
///
/// Each method maps to a specific MangaDex endpoint and returns a
/// strongly-typed result. Network or parsing failures are caught internally
/// and surfaced as empty collections rather than thrown exceptions, keeping
/// the calling UI layer simple.
class ApiService {
  /// Root URL for every MangaDex API call.
  static const String baseUrl = 'https://api.mangadex.org';

  /// Query-string fragment appended to requests that return manga listings.
  ///
  /// Restricts results to `safe` and `suggestive` content ratings, filtering
  /// out explicit / pornographic entries at the API level.
  static const String safeFilter =
      '&contentRating[]=safe&contentRating[]=suggestive';

  // ── 1. Home List ──────────────────────────────────────────────────────────

  /// Fetches the first 20 manga entries used to populate the home screen.
  ///
  /// Includes the `cover_art` relationship so that [Manga.fromJson] can
  /// extract the cover filename without a second request.
  ///
  /// Returns an empty list if the request fails or returns a non-200 status.
  Future<List<Manga>> fetchMangaList() async {
    final response = await http.get(
      Uri.parse('$baseUrl/manga?limit=20&includes[]=cover_art$safeFilter'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // `data` is a JSON array; each element is passed to Manga.fromJson.
      return (data['data'] as List).map((m) => Manga.fromJson(m)).toList();
    }
    return [];
  }

  // ── 2. Chapter List ───────────────────────────────────────────────────────

  /// Fetches up to 100 English chapters for the manga identified by [mangaId],
  /// sorted in ascending chapter order.
  ///
  /// `includeExternalUrl=0` excludes chapters that only link out to an
  /// external site (e.g. official publisher pages) and have no readable pages
  /// on MangaDex itself.
  ///
  /// Each map in the returned list contains:
  /// - `id`      — Chapter UUID used to fetch pages.
  /// - `chapter` — Chapter number string (e.g. `"12"`), or `"?"` if absent.
  /// - `title`   — Chapter title, falling back to `"Chapter <number>"`.
  ///
  /// Returns an empty list on any network or parsing error.
  Future<List<Map<String, dynamic>>> fetchChapters(String mangaId) async {
    try {
      final url =
          '$baseUrl/manga/$mangaId/feed?limit=100&translatedLanguage[]=en&order[chapter]=asc&includeExternalUrl=0$safeFilter';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> chapters = data['data'];
        return chapters
            .map((chap) => {
                  'id': chap['id'],
                  // Null-coerce missing chapter numbers to '?' to avoid UI crashes.
                  'chapter': chap['attributes']['chapter'] ?? '?',
                  // Fall back to a generated title when the API omits one.
                  'title': chap['attributes']['title'] ??
                      'Chapter ${chap['attributes']['chapter']}',
                })
            .toList();
      }
    } catch (e) {
      debugPrint("Chapter Fetch Error: $e");
    }
    return [];
  }

  // ── 3. Page URLs ──────────────────────────────────────────────────────────

  /// Resolves the full image URLs for every page in the chapter identified
  /// by [chapterId].
  ///
  /// MangaDex uses a two-step process:
  /// 1. Call `/at-home/server/<chapterId>` to receive the CDN base URL and
  ///    the chapter's content hash + file list.
  /// 2. Assemble each URL as `<baseUrl>/data/<hash>/<filename>`.
  ///
  /// The `/data/` path serves full-quality images. Use `/data-saver/` instead
  /// for compressed versions (not currently implemented here).
  ///
  /// Returns an empty list on any network or parsing error.
  Future<List<String>> fetchPagesByChapterId(String chapterId) async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/at-home/server/$chapterId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String host =
            data['baseUrl']; // CDN host assigned to this session.
        final String hash =
            data['chapter']['hash']; // Unique hash for this chapter's assets.
        final List<dynamic> files =
            data['chapter']['data']; // Ordered list of image filenames.
        // Combine the three parts to build an absolute URL for each page.
        return files.map((f) => '$host/data/$hash/$f').toList();
      }
    } catch (e) {
      debugPrint("Page Fetch Error: $e");
    }
    return [];
  }

  // ── 4. Search ─────────────────────────────────────────────────────────────

  /// Searches for manga whose title matches [title], returning up to 15 results.
  ///
  /// Includes `cover_art` in the response so thumbnails can be displayed on
  /// the search results screen without additional requests.
  ///
  /// Returns an empty list if the request fails or returns a non-200 status.
  Future<List<Manga>> searchManga(String title) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/manga?title=$title&limit=15&includes[]=cover_art$safeFilter'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['data'] as List).map((m) => Manga.fromJson(m)).toList();
    }
    return [];
  }

  // ── 5. Genre Tags ─────────────────────────────────────────────────────────

  /// Fetches the genre tags for the manga identified by [mangaId] and returns
  /// them as a comma-separated string (e.g. `"Action, Adventure, Fantasy"`).
  ///
  /// MangaDex organises tags by `group`; this method filters for the `"genre"`
  /// group only and ignores theme, format, and content tags. Tags without an
  /// English name are also excluded to avoid blank entries.
  ///
  /// Returns `"Manga"` as a safe fallback when:
  /// - No genre tags are present.
  /// - The network request fails.
  /// - The response cannot be parsed.
  Future<String> fetchGenre(String mangaId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/manga/$mangaId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final attrs = data['data']['attributes'] ?? {};
        final tags = attrs['tags'] as List? ?? [];
        final genres = tags
            // Keep only tags that belong to the 'genre' group and have an English name.
            .where((tag) =>
                tag['attributes']?['group'] == 'genre' &&
                tag['attributes']?['name']?['en'] != null)
            .map<String>((tag) => tag['attributes']['name']['en'] as String)
            .toList();
        return genres.isNotEmpty ? genres.join(', ') : 'Manga';
      }
    } catch (e) {
      debugPrint("Genre Fetch Error: $e");
    }
    return 'Manga';
  }
}
