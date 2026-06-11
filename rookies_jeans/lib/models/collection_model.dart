class CollectionModel {
  final String id;
  final String title;
  final String handle;
  final String description;
  final String imageUrl;

  const CollectionModel({
    required this.id,
    required this.title,
    required this.handle,
    required this.description,
    required this.imageUrl,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    return CollectionModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      handle: json['handle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageUrl: json['image']?['url'] as String? ?? '',
    );
  }
}