class ShopifyCollection {
  final String id;
  final String title;
  final String handle;
  final String? imageUrl;
  final String label; // display label e.g. "CARGOS"

  const ShopifyCollection({
    required this.id,
    required this.title,
    required this.handle,
    this.imageUrl,
    required this.label,
  });

  factory ShopifyCollection.fromJson(
    Map<String, dynamic> json, {
    required String label,
  }) {
    return ShopifyCollection(
      id: json['id'] as String,
      title: json['title'] as String,
      handle: json['handle'] as String,
      imageUrl: json['image']?['url'] as String?,
      label: label,
    );
  }
}