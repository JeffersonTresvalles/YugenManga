class Manga {
  final String id;
  final String title;
  final String description;
  final String? coverFileName;
  final String? rawCoverUrl;

  Manga({
    required this.id,
    required this.title,
    required this.description,
    this.coverFileName,
    this.rawCoverUrl,
  });

  factory Manga.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] ?? {};

    String titleStr = 'No Title';
    if (attrs['title'] != null && attrs['title'] is Map) {
      titleStr = attrs['title']['en'] ?? attrs['title'].values.first;
    }

    String descStr = 'No description available.';
    if (attrs['description'] != null && attrs['description'] is Map) {
      descStr = attrs['description']['en'] ?? 'No description available.';
    }

    String? coverFile;
    if (json['relationships'] != null) {
      for (var rel in json['relationships']) {
        if (rel['type'] == 'cover_art' && rel['attributes'] != null) {
          coverFile = rel['attributes']['fileName'];
        }
      }
    }

    return Manga(
      id: json['id'],
      title: titleStr,
      description: descStr,
      coverFileName: coverFile,
    );
  }

  String get coverUrl =>
      rawCoverUrl ??
      (coverFileName != null
          ? 'https://uploads.mangadex.org/covers/$id/$coverFileName'
          : 'https://via.placeholder.com/300x450.png?text=No+Cover');
}
