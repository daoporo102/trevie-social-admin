class ToxicImage {
  final String url;
  final int index;
  final String reason;
  final double score;

  ToxicImage({
    required this.url,
    required this.index,
    required this.reason,
    required this.score,
  });

  factory ToxicImage.fromJson(Map<String, dynamic> json) {
    return ToxicImage(
      url: json['url'] ?? '',
      index: json['index'] ?? 0,
      reason: json['reason'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'index': index,
      'reason': reason,
      'score': score,
    };
  }
}