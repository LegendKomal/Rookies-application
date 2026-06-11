class ProductModel {
  final String id;
  final String title;
  final String handle;
  final String imageUrl;
  final String imageAlt;
  final double price;
  final double? compareAtPrice;
  final String currencyCode;

  const ProductModel({
    required this.id,
    required this.title,
    required this.handle,
    required this.imageUrl,
    required this.imageAlt,
    required this.price,
    required this.compareAtPrice,
    required this.currencyCode,
  });

  bool get hasDiscount => compareAtPrice != null && compareAtPrice! > price;

  String get formattedPrice => '₹${price.toStringAsFixed(0)}';

  String get formattedCompareAt =>
      compareAtPrice == null ? '' : '₹${compareAtPrice!.toStringAsFixed(0)}';

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final featuredImage = json['featuredImage'] as Map<String, dynamic>?;
    final images = json['images']?['nodes'] as List?;
    final fallbackImage = images != null && images.isNotEmpty
        ? images.first as Map<String, dynamic>
        : null;
    final image = featuredImage ?? fallbackImage;

    final priceString =
        (json['priceRange'] as Map<String, dynamic>?)?['minVariantPrice'] != null
            ? ((json['priceRange'] as Map<String, dynamic>)['minVariantPrice']
                as Map<String, dynamic>)['amount'] as String? ?? '0'
            : '0';

    final compareAtPriceNode =
        (json['compareAtPriceRange'] as Map<String, dynamic>?)?['minVariantPrice']
            as Map<String, dynamic>?;

    final compareAtString = compareAtPriceNode?['amount'] as String?;

    final priceNode =
        (json['priceRange'] as Map<String, dynamic>?)?['minVariantPrice']
            as Map<String, dynamic>?;

    return ProductModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      handle: json['handle'] as String? ?? '',
      imageUrl: image?['url'] as String? ?? '',
      imageAlt: image?['altText'] as String? ?? '',
      price: double.tryParse(priceString) ?? 0,
      compareAtPrice:
          compareAtString == null ? null : double.tryParse(compareAtString),
      currencyCode: priceNode?['currencyCode'] as String? ?? 'INR',
    );
  }
}