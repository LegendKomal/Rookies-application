// Models for the home-screen content managed through the Shopify metaobjects
// the admin panel (rookies-admin-panel/) edits: promo_block, shop_the_look,
// occasion_tile, instagram_post. `home_banner` already had a model in
// banner_model.dart.
//
// Each `fromMetaobjectJson` expects a node shaped by the field-aliased
// GraphQL query in ShopifyStorefrontService (see e.g. _fetchPromoBlocks),
// i.e. `{ id, image: {...}, label: {...}, sort_order: {...}, ... }` rather
// than the raw `fields: [...]` array shape.

import 'package:rookies_jeans/models/product_model.dart';

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

String? _imageUrlFrom(Map<String, dynamic>? field) {
  return field?['reference']?['image']?['url'] as String?;
}

String? _textFrom(Map<String, dynamic>? field) => field?['value'] as String?;

class PromoBlockContent {
  final String id;
  final String? imageUrl;
  final String label;
  final String? buttonLabel;
  final String collectionHandle;
  final int sortOrder;

  const PromoBlockContent({
    required this.id,
    this.imageUrl,
    required this.label,
    this.buttonLabel,
    required this.collectionHandle,
    this.sortOrder = 0,
  });

  factory PromoBlockContent.fromMetaobjectJson(Map<String, dynamic> json) {
    return PromoBlockContent(
      id: json['id'] as String,
      imageUrl: _imageUrlFrom(json['image']),
      label: _textFrom(json['label']) ?? '',
      buttonLabel: _textFrom(json['button_label']),
      collectionHandle: _textFrom(json['collection_handle']) ?? '',
      sortOrder: _asInt(_textFrom(json['sort_order'])) ?? 0,
    );
  }
}

class ExploreCategoryContent {
  final String id;
  final String? imageUrl;
  final String label;
  final String collectionHandle;
  final String section;
  final int sortOrder;

  const ExploreCategoryContent({
    required this.id,
    this.imageUrl,
    required this.label,
    required this.collectionHandle,
    required this.section,
    this.sortOrder = 0,
  });

  bool get isBottomwear => section.trim().toLowerCase() == 'bottom';

  factory ExploreCategoryContent.fromMetaobjectJson(Map<String, dynamic> json) {
    return ExploreCategoryContent(
      id: json['id'] as String,
      imageUrl: _imageUrlFrom(json['image']),
      label: _textFrom(json['label']) ?? '',
      collectionHandle: _textFrom(json['collection_handle']) ?? '',
      section: _textFrom(json['section']) ?? 'top',
      sortOrder: _asInt(_textFrom(json['sort_order'])) ?? 0,
    );
  }
}

class ShopTheLookEntry {
  final String id;
  final String? imageUrl;
  final int sortOrder;
  final List<ShopifyProduct> products;

  const ShopTheLookEntry({
    required this.id,
    this.imageUrl,
    this.sortOrder = 0,
    this.products = const [],
  });

  factory ShopTheLookEntry.fromMetaobjectJson(Map<String, dynamic> json) {
    final edges = (json['products']?['references']?['edges'] as List?) ?? [];
    return ShopTheLookEntry(
      id: json['id'] as String,
      imageUrl: _imageUrlFrom(json['image']),
      sortOrder: _asInt(_textFrom(json['sort_order'])) ?? 0,
      products: edges
          .map((e) => ShopifyProduct.fromJson(e['node'] as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OccasionTileContent {
  final String id;
  final String? imageUrl;
  final String? label;
  final String collectionHandle;
  final int sortOrder;

  const OccasionTileContent({
    required this.id,
    this.imageUrl,
    this.label,
    required this.collectionHandle,
    this.sortOrder = 0,
  });

  factory OccasionTileContent.fromMetaobjectJson(Map<String, dynamic> json) {
    return OccasionTileContent(
      id: json['id'] as String,
      imageUrl: _imageUrlFrom(json['image']),
      label: _textFrom(json['label']),
      collectionHandle: _textFrom(json['collection_handle']) ?? '',
      sortOrder: _asInt(_textFrom(json['sort_order'])) ?? 0,
    );
  }
}

class InstagramPostContent {
  final String id;
  final String? imageUrl;
  final String postUrl;
  final String username;
  final int sortOrder;

  const InstagramPostContent({
    required this.id,
    this.imageUrl,
    required this.postUrl,
    this.username = '',
    this.sortOrder = 0,
  });

  factory InstagramPostContent.fromMetaobjectJson(Map<String, dynamic> json) {
    return InstagramPostContent(
      id: json['id'] as String,
      imageUrl: _imageUrlFrom(json['image']),
      postUrl: _textFrom(json['post_url']) ?? '',
      username: _textFrom(json['username']) ?? '',
      sortOrder: _asInt(_textFrom(json['sort_order'])) ?? 0,
    );
  }
}
