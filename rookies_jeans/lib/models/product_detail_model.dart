import 'dart:convert';

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
  final String? shippingInfo;
  final String? careInstructions;
  final String vendor;
  final String productType;
  final List<String> tags;
  final List<String> collectionIds;

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
    this.shippingInfo,
    this.careInstructions,
    this.vendor = '',
    this.productType = '',
    this.tags = const [],
    this.collectionIds = const [],
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
    final images = imgEdges.map((e) => e['node']['url'] as String).toList();

    final varEdges = (json['variants']?['edges'] as List?) ?? [];
    final variants = varEdges
        .map((e) =>
            ProductDetailVariant.fromJson(e['node'] as Map<String, dynamic>))
        .toList();

    final optList = (json['options'] as List?) ?? [];
    final options = optList
        .map((o) => ProductDetailOption.fromJson(o as Map<String, dynamic>))
        .toList();

    final collectionEdges = (json['collections']?['edges'] as List?) ?? [];
    final collectionIds = collectionEdges
        .map((e) => (e['node']['id'] as String).split('/').last)
        .toList();

    return ShopifyProductDetail(
      id: json['id'] as String,
      title: json['title'] as String,
      handle: json['handle'] as String,
      description: json['description'] as String? ?? '',
      price: double.tryParse(priceStr) ?? 0,
      compareAtPrice: compareStr != null ? double.tryParse(compareStr) : null,
      currencyCode: currency,
      imageUrls: images,
      variants: variants,
      options: options,
      shippingInfo: json['shippingInfo']?['value'] as String?,
      careInstructions: json['careInstructions']?['value'] as String?,
      vendor: json['vendor'] as String? ?? '',
      productType: json['productType'] as String? ?? '',
      tags: ((json['tags'] as List?) ?? []).cast<String>(),
      collectionIds: collectionIds,
    );
  }
}

/// A single metafield attached to a product variant
/// (e.g. custom.fit, custom.material, custom.fabric).
class VariantMetafield {
  final String namespace;
  final String key;
  final String value;
  final String type;

  const VariantMetafield({
    required this.namespace,
    required this.key,
    required this.value,
    required this.type,
  });

  /// Human-friendly label derived from the metafield key.
  /// e.g. "fabric_composition" -> "FABRIC COMPOSITION"
  String get label => key.replaceAll('_', ' ').toUpperCase();

  /// Human-friendly value.
  /// - Shopify "list.*" metafield types are stored as a JSON-encoded
  ///   array string (e.g. '["Cotton","Elastane"]') and are rendered
  ///   here as a comma-separated list.
  /// - "boolean" metafields ("true"/"false") render as Yes/No.
  /// - Everything else is returned as-is.
  String get formattedValue {
    if (type.startsWith('list.')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).join(', ');
        }
      } catch (_) {
        // Not valid JSON - fall back to the raw value below.
      }
    }
    if (type == 'boolean') {
      return value.toLowerCase() == 'true' ? 'Yes' : 'No';
    }
    return value;
  }

  factory VariantMetafield.fromJson(Map<String, dynamic> json) =>
      VariantMetafield(
        namespace: json['namespace'] as String? ?? '',
        key: json['key'] as String? ?? '',
        value: json['value'] as String? ?? '',
        type: json['type'] as String? ?? '',
      );
}

class ProductDetailVariant {
  final String id;
  final String title;
  final bool availableForSale;
  final double? price;
  final double? compareAtPrice;
  final List<SelectedDetailOption> selectedOptions;
  final List<VariantMetafield> metafields;

  const ProductDetailVariant({
    required this.id,
    required this.title,
    required this.availableForSale,
    this.price,
    this.compareAtPrice,
    required this.selectedOptions,
    this.metafields = const [],
  });

  /// Convenience lookup by key (namespace defaults to "custom").
  String? metafield(String key, {String namespace = 'custom'}) {
    for (final m in metafields) {
      if (m.key == key && m.namespace == namespace) return m.value;
    }
    return null;
  }

  factory ProductDetailVariant.fromJson(Map<String, dynamic> json) =>
      ProductDetailVariant(
        id: json['id'] as String,
        title: json['title'] as String,
        availableForSale: json['availableForSale'] as bool? ?? false,
        price: double.tryParse(json['priceV2']?['amount'] as String? ?? ''),
        compareAtPrice: double.tryParse(
            json['compareAtPriceV2']?['amount'] as String? ?? ''),
        selectedOptions: ((json['selectedOptions'] as List?) ?? [])
            .map((o) =>
                SelectedDetailOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        // Shopify returns a `null` entry in the metafields list for any
        // identifier that doesn't have a value set on that variant, so
        // those are filtered out here.
        metafields: ((json['metafields'] as List?) ?? [])
            .where((m) => m != null)
            .map((m) => VariantMetafield.fromJson(m as Map<String, dynamic>))
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

class ProductDetailOptionValue {
  final String name;
  final String? swatchColorHex; // e.g. "#E63946"
  final String? swatchImageUrl;

  const ProductDetailOptionValue({
    required this.name,
    this.swatchColorHex,
    this.swatchImageUrl,
  });

  factory ProductDetailOptionValue.fromJson(Map<String, dynamic> json) {
    final swatch = json['swatch'] as Map<String, dynamic>?;
    return ProductDetailOptionValue(
      name: json['name'] as String,
      swatchColorHex: swatch?['color'] as String?,
      swatchImageUrl:
          swatch?['image']?['previewImage']?['url'] as String?,
    );
  }
}

class ProductDetailOption {
  final String name;
  final List<String> values;
  final List<ProductDetailOptionValue> optionValues;

  const ProductDetailOption({
    required this.name,
    required this.values,
    this.optionValues = const [],
  });

  bool get isColorOption =>
      name.toLowerCase() == 'color' || name.toLowerCase() == 'colour';

  /// Swatch info for a given option value, if linked to one.
  ProductDetailOptionValue? swatchFor(String valueName) {
    for (final v in optionValues) {
      if (v.name == valueName) return v;
    }
    return null;
  }

  factory ProductDetailOption.fromJson(Map<String, dynamic> json) {
    final rawValues = (json['optionValues'] as List?) ?? [];
    return ProductDetailOption(
      name: json['name'] as String,
      values: ((json['values'] as List?) ?? []).cast<String>(),
      optionValues: rawValues
          .map((v) =>
              ProductDetailOptionValue.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}