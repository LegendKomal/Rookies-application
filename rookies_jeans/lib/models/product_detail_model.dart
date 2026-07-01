class ShopifyProductDetail {
  final String id;
  final String title;
  final String handle;
  final String description;
  final double price;
  final double? compareAtPrice;
  final String currencyCode;
  final List<String> imageUrls;
  final List<ProductDetailVariant> variants;
  final List<ProductDetailOption> options;
  final String? shippingInfo;      // ✅ NEW
  final String? careInstructions;

  const ShopifyProductDetail({
    required this.id,
    required this.title,
    required this.handle,
    required this.description,
    required this.price,
    this.compareAtPrice,
    required this.currencyCode,
    required this.imageUrls,
    required this.variants,
    required this.options,
    this.shippingInfo,             // ✅ NEW
    this.careInstructions,
  });

  bool get isOnSale => compareAtPrice != null && compareAtPrice! > price;

  String get formattedPrice => currencyCode == 'INR'
    ? price.toStringAsFixed(0)
    : '$currencyCode ${price.toStringAsFixed(2)}';

  String get formattedCompareAtPrice {
    if (compareAtPrice == null) return '';
    return currencyCode == 'INR'
        ? compareAtPrice!.toStringAsFixed(0)
        : '$currencyCode ${compareAtPrice!.toStringAsFixed(2)}';
  }

  factory ShopifyProductDetail.fromJson(Map<String, dynamic> json) {
    final priceStr =
        json['priceRange']?['minVariantPrice']?['amount'] as String? ?? '0';
    final compareStr =
        json['compareAtPriceRange']?['minVariantPrice']?['amount'] as String?;
    final currency =
        json['priceRange']?['minVariantPrice']?['currencyCode'] as String? ??
            'INR';

    final imgEdges = (json['images']?['edges'] as List?) ?? [];
    final images =
        imgEdges.map((e) => e['node']['url'] as String).toList();

    final varEdges = (json['variants']?['edges'] as List?) ?? [];
    final variants = varEdges
        .map((e) => ProductDetailVariant.fromJson(
            e['node'] as Map<String, dynamic>))
        .toList();

    final optList = (json['options'] as List?) ?? [];
    final options = optList
        .map((o) =>
            ProductDetailOption.fromJson(o as Map<String, dynamic>))
        .toList();

    return ShopifyProductDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      handle: json['handle'] as String,
      description: json['description'] as String? ?? '',
      price: double.tryParse(priceStr) ?? 0,
      compareAtPrice:
          compareStr != null ? double.tryParse(compareStr) : null,
      currencyCode: currency,
      imageUrls: images,
      variants: variants,
      options: options,
      shippingInfo: json['shippingInfo']?['value'] as String?,
      careInstructions: json['careInstructions']?['value'] as String?,
    );
  }
}

class ProductDetailVariant {
  final String id;
  final String title;
  final bool availableForSale;
  final double? price;
  final double? compareAtPrice;
  final List<SelectedDetailOption> selectedOptions;

  const ProductDetailVariant({
    required this.id,
    required this.title,
    required this.availableForSale,
    this.price,
    this.compareAtPrice,
    required this.selectedOptions,
  });

  factory ProductDetailVariant.fromJson(Map<String, dynamic> json) =>
      ProductDetailVariant(
        id: json['id'] as String,
        title: json['title'] as String,
        availableForSale: json['availableForSale'] as bool? ?? false,
        price: double.tryParse(
            json['priceV2']?['amount'] as String? ?? ''),
        compareAtPrice: double.tryParse(
            json['compareAtPriceV2']?['amount'] as String? ?? ''),
        selectedOptions:
            ((json['selectedOptions'] as List?) ?? [])
                .map((o) => SelectedDetailOption.fromJson(
                    o as Map<String, dynamic>))
                .toList(),
      );
}

class SelectedDetailOption {
  final String name;
  final String value;
  const SelectedDetailOption({required this.name, required this.value});
  factory SelectedDetailOption.fromJson(Map<String, dynamic> json) =>
      SelectedDetailOption(
        name: json['name'] as String,
        value: json['value'] as String,
      );
}

class ProductDetailOption {
  final String name;
  final List<String> values;

  const ProductDetailOption({required this.name, required this.values});

  factory ProductDetailOption.fromJson(Map<String, dynamic> json) =>
      ProductDetailOption(
        name: json['name'] as String,
        values: ((json['values'] as List?) ?? []).cast<String>(),
      );
}