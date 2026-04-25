class ArticleReference {
  final String articleNumber; // String to support 9A, 175A, 2A etc.
  final String title;
  final String? excerpt;
  final String? amendment;

  const ArticleReference({
    required this.articleNumber,
    required this.title,
    this.excerpt,
    this.amendment,
  });

  Map<String, dynamic> toMap() {
    return {
      'article_number': articleNumber,
      'title': title,
      'excerpt': excerpt,
      'amendment': amendment,
    };
  }

  factory ArticleReference.fromMap(Map<String, dynamic> map) {
    final raw = map['article_number'];
    final articleNumber = raw == null
        ? '?'
        : raw is int
            ? raw.toString()
            : raw is double
                ? raw.toInt().toString()
                : raw.toString().trim();

    return ArticleReference(
      articleNumber: articleNumber,
      title: map['title'] as String? ?? '',
      excerpt: map['excerpt'] as String?,
      amendment: map['amendment'] as String?,
    );
  }
}