/// A single filter facet returned by Shopify's Storefront API
/// (e.g. "Size", "Color", "Availability", "Price").
class ShopifyFilter {
  final String id;
  final String label;
  final String type; // LIST, PRICE_RANGE, BOOLEAN
  final List<ShopifyFilterValue> values;

  const ShopifyFilter({
    required this.id,
    required this.label,
    required this.type,
    required this.values,
  });

  factory ShopifyFilter.fromJson(Map<String, dynamic> json) {
    final valuesList = (json['values'] as List?) ?? [];
    return ShopifyFilter(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? 'LIST',
      values: valuesList
          .map((v) => ShopifyFilterValue.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single selectable value within a [ShopifyFilter], e.g. "Blue" under
/// the "Color" filter, or "$0 - $50" under "Price".
///
/// [input] is the raw JSON string Shopify expects you to pass back,
/// unmodified, inside the `filters` argument of the products query.
class ShopifyFilterValue {
  final String id;
  final String label;
  final int count;
  final String input;

  const ShopifyFilterValue({
    required this.id,
    required this.label,
    required this.count,
    required this.input,
  });

  factory ShopifyFilterValue.fromJson(Map<String, dynamic> json) {
    return ShopifyFilterValue(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      input: json['input'] as String? ?? '{}',
    );
  }
}

class ShopifyProduct {
  final String id;
  final String title;
  final String handle;
  final double price;
  final double? compareAtPrice;
  final String currencyCode;
  final List<String> imageUrls;
  final List<ProductVariant> variants;
  final List<ProductOption> options;

  const ShopifyProduct({
    required this.id,
    required this.title,
    required this.handle,
    required this.price,
    this.compareAtPrice,
    required this.currencyCode,
    required this.imageUrls,
    required this.variants,
    required this.options,
  });

  bool get isOnSale => compareAtPrice != null && compareAtPrice! > price;

  String get formattedPrice => currencyCode == 'INR'
    ? price.toStringAsFixed(0)
    : price.toStringAsFixed(2);

String get formattedCompareAtPrice {
  if (compareAtPrice == null) return '';
  return currencyCode == 'INR'
      ? compareAtPrice!.toStringAsFixed(0)
      : compareAtPrice!.toStringAsFixed(2);
}
  String? get primaryImageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  List<String> get colorHexCodes {
    for (final opt in options) {
      if (opt.name.toUpperCase() == 'COLOR' ||
          opt.name.toUpperCase() == 'COLOUR') {
        return opt.optionValues
            .where((v) => v.swatchColor != null)
            .map((v) => v.swatchColor!)
            .toSet()   // deduplicate
            .toList();
      }
    }
    return [];
  }

  factory ShopifyProduct.fromJson(Map<String, dynamic> json) {
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
            ProductVariant.fromJson(e['node'] as Map<String, dynamic>))
        .toList();

    final optList = (json['options'] as List?) ?? [];
    final options = optList
        .map((o) => ProductOption.fromJson(o as Map<String, dynamic>))
        .toList();

    return ShopifyProduct(
      id: json['id'] as String,
      title: json['title'] as String,
      handle: json['handle'] as String,
      price: double.tryParse(priceStr) ?? 0,
      compareAtPrice: compareStr != null ? double.tryParse(compareStr) : null,
      currencyCode: currency,
      imageUrls: images,
      variants: variants,
      options: options,
    );
  }
}

class ProductVariant {
  final String id;
  final String title;
  final bool availableForSale;
  final List<SelectedOption> selectedOptions;

  const ProductVariant({
    required this.id,
    required this.title,
    required this.availableForSale,
    required this.selectedOptions,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        id: json['id'] as String,
        title: json['title'] as String,
        availableForSale: json['availableForSale'] as bool? ?? false,
        selectedOptions: ((json['selectedOptions'] as List?) ?? [])
            .map((o) => SelectedOption.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}

class SelectedOption {
  final String name;
  final String value;
  const SelectedOption({required this.name, required this.value});
  factory SelectedOption.fromJson(Map<String, dynamic> json) => SelectedOption(
        name: json['name'] as String,
        value: json['value'] as String,
      );
}

class ProductOption {
  final String name;
  final List<String> values;
  final List<OptionValue> optionValues;

  const ProductOption({
    required this.name,
    required this.values,
    required this.optionValues,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    final ovList = (json['optionValues'] as List?) ?? [];
    return ProductOption(
      name: json['name'] as String,
      values: ((json['values'] as List?) ?? []).cast<String>(),
      optionValues:
          ovList.map((o) => OptionValue.fromJson(o as Map<String, dynamic>)).toList(),
    );
  }
}

class OptionValue {
  final String name;
  final String? swatchColor;

  const OptionValue({required this.name, this.swatchColor});

  factory OptionValue.fromJson(Map<String, dynamic> json) {
    final rawColor = json['swatch']?['color'] as String?;
    return OptionValue(
      name: json['name'] as String,
      swatchColor: rawColor,
    );
  }
}