class BannerModel {
  final String desktopImageUrl;
  final String mobileImageUrl;
  final String heading;
  final String subheading;
  final String buttonText;
  final String link;

  const BannerModel({
    required this.desktopImageUrl,
    required this.mobileImageUrl,
    required this.heading,
    required this.subheading,
    required this.buttonText,
    required this.link,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    final fields = json['fields'] as List? ?? [];

    String valueOf(String key) {
      final field = fields.cast<Map>().firstWhere(
            (e) => e['key'] == key,
            orElse: () => <String, dynamic>{},
          );
      return field['value'] as String? ?? '';
    }

    String imageOf(String key) {
      final field = fields.cast<Map>().firstWhere(
            (e) => e['key'] == key,
            orElse: () => <String, dynamic>{},
          );
      return field['reference']?['image']?['url'] as String? ?? '';
    }

    return BannerModel(
      desktopImageUrl: imageOf('image_desktop'),
      mobileImageUrl: imageOf('image_mobile'),
      heading: valueOf('heading'),
      subheading: valueOf('subheading'),
      buttonText: valueOf('button_text'),
      link: valueOf('link'),
    );
  }
}