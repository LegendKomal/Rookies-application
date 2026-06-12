class HomeBanner {
  final String id;
  final String? imageUrl;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final String? ctaUrl;

  const HomeBanner({
    required this.id,
    this.imageUrl,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.ctaUrl,
  });

  factory HomeBanner.fromMetaobjectJson(Map<String, dynamic> json) {
    final fields = (json['fields'] as List?) ?? [];
    String title = '', subtitle = '', ctaLabel = '', ctaUrl = '';
    String? imageUrl;

    for (final f in fields) {
      switch (f['key'] as String) {
        case 'title':    title    = f['value'] as String? ?? ''; break;
        case 'subtitle': subtitle = f['value'] as String? ?? ''; break;
        case 'cta_label': ctaLabel = f['value'] as String? ?? ''; break;
        case 'cta_url':  ctaUrl   = f['value'] as String? ?? ''; break;
        case 'image':
          imageUrl = f['reference']?['image']?['url'] as String?;
          break;
      }
    }

    return HomeBanner(
      id: json['id'] as String,
      imageUrl: imageUrl,
      title: title,
      subtitle: subtitle,
      ctaLabel: ctaLabel.isNotEmpty ? ctaLabel : null,
      ctaUrl: ctaUrl.isNotEmpty ? ctaUrl : null,
    );
  }
}