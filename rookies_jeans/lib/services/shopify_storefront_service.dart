import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/models/banner_model.dart';
import 'package:rookies_jeans/models/collection_model.dart';

class ShopifyStorefrontService {
  ShopifyStorefrontService._();
  static final ShopifyStorefrontService instance = ShopifyStorefrontService._();

  void _log(String msg) {
    if (kDebugMode) debugPrint('[ShopifyStorefrontService] $msg');
  }

  Future<List<ShopifyProduct>> getProductsByCollection(
    String handle, {
    int first = 10,
  }) async {
    const String query = r'''
  query getCollectionProducts($handle: String!, $first: Int!) {
    collectionByHandle(handle: $handle) {
      products(first: $first) {
        edges {
          node {
            id
            title
            handle
            priceRange {
              minVariantPrice { amount currencyCode }
            }
            compareAtPriceRange {
              minVariantPrice { amount currencyCode }
            }
            images(first: 2) {
              edges { node { url altText } }
            }
            options {
              name
              values
              optionValues {
                name
                swatch {
                  color
                }
              }
            }
            variants(first: 10) {
              edges {
                node {
                  id
                  title
                  availableForSale
                  selectedOptions {
                    name
                    value
                  }
                }
              }
            }
          }
        }
      }
    }
  }
''';

    try {
      final response = await http.post(
        Uri.parse(ShopifyConstants.storefrontEndpoint),
        headers: ShopifyConstants.headers,
        body: jsonEncode({
          'query': query,
          'variables': {'handle': handle, 'first': first},
        }),
      );
      _log('getProductsByCollection [$handle] → ${response.statusCode}');
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['errors'] != null) {
        _log('errors: ${decoded['errors']}');
        return [];
      }
      final collection = decoded['data']?['collectionByHandle'];
      if (collection == null) return [];
      final edges = (collection['products']['edges'] as List?) ?? [];
      return edges
          .map((e) => ShopifyProduct.fromJson(e['node'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('EXCEPTION: $e');
      return [];
    }
  }

  Future<List<ShopifyCollection>> getLatestDropCollections() async {
    final handles = ShopifyConstants.latestDropCollections;
    final buffer = StringBuffer('query latestDropCollections {\n');
    for (int i = 0; i < handles.length; i++) {
      buffer.write('  c$i: collectionByHandle(handle: "${handles[i]['handle']}") {\n');
      buffer.write('    id title handle\n');
      buffer.write('    image { url altText }\n');
      buffer.write('  }\n');
    }
    buffer.write('}');

    try {
      final response = await http.post(
        Uri.parse(ShopifyConstants.storefrontEndpoint),
        headers: ShopifyConstants.headers,
        body: jsonEncode({'query': buffer.toString()}),
      );
      _log('getLatestDropCollections → ${response.statusCode}');
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['errors'] != null || decoded['data'] == null) return [];
      final data = decoded['data'] as Map<String, dynamic>;
      final List<ShopifyCollection> result = [];
      for (int i = 0; i < handles.length; i++) {
        final c = data['c$i'];
        if (c != null) {
          result.add(ShopifyCollection.fromJson(
            c as Map<String, dynamic>,
            label: handles[i]['label']!,
          ));
        }
      }
      return result;
    } catch (e) {
      _log('getLatestDropCollections EXCEPTION: $e');
      return [];
    }
  }

  Future<List<ShopifyCollection>> getOurCollectionTiles() async {
    final tiles = ShopifyConstants.ourCollectionTiles;
    final buffer = StringBuffer('query ourCollectionTiles {\n');
    for (int i = 0; i < tiles.length; i++) {
      buffer.write('  c$i: collectionByHandle(handle: "${tiles[i]['handle']}") {\n');
      buffer.write('    id title handle\n');
      buffer.write('    image { url altText }\n');
      buffer.write('  }\n');
    }
    buffer.write('}');

    try {
      final response = await http.post(
        Uri.parse(ShopifyConstants.storefrontEndpoint),
        headers: ShopifyConstants.headers,
        body: jsonEncode({'query': buffer.toString()}),
      );
      _log('getOurCollectionTiles → ${response.statusCode}');
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['errors'] != null || decoded['data'] == null) return [];
      final data = decoded['data'] as Map<String, dynamic>;
      final List<ShopifyCollection> result = [];
      for (int i = 0; i < tiles.length; i++) {
        final c = data['c$i'];
        if (c != null) {
          result.add(ShopifyCollection.fromJson(
            c as Map<String, dynamic>,
            label: tiles[i]['label']!,
          ));
        }
      }
      return result;
    } catch (e) {
      _log('getOurCollectionTiles EXCEPTION: $e');
      return [];
    }
  }

  Future<BalloonBannerData?> getBalloonBanner() async {
    const String query = r'''
      query getBalloonBanner {
        collection: collectionByHandle(handle: "balloonfit-cargo") {
          title
          description
          image { url }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(ShopifyConstants.storefrontEndpoint),
        headers: ShopifyConstants.headers,
        body: jsonEncode({'query': query}),
      );
      _log('getBalloonBanner → ${response.statusCode}');
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['errors'] != null || decoded['data'] == null) return null;
      final c = decoded['data']['collection'];
      if (c == null) return null;
      return BalloonBannerData(
        title: (c['title'] as String? ?? 'BALLOON FIT CARGO PANTS').toUpperCase(),
        description: c['description'] as String? ?? '',
        imageUrl: c['image']?['url'] as String?,
      );
    } catch (e) {
      _log('getBalloonBanner EXCEPTION: $e');
      return null;
    }
  }

  Future<List<HomeBanner>> getHomeBanners() async {
  const String query = r'''
    query getHomeBanners {
      metaobjects(type: "home_banner", first: 10) {
        edges {
          node {
            id
            fields {
              key
              value
              reference {
                ... on MediaImage {
                  image { url }
                }
              }
            }
          }
        }
      }
    }
  ''';

  try {
    final response = await http.post(
      Uri.parse(ShopifyConstants.storefrontEndpoint),
      headers: ShopifyConstants.headers,
      body: jsonEncode({'query': query}),
    );
    _log('getHomeBanners → ${response.statusCode}');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (decoded['errors'] != null || decoded['data'] == null) {
      _log('getHomeBanners errors: ${decoded['errors']}');
      return _staticBanners();
    }

    final edges =
        (decoded['data']['metaobjects']['edges'] as List?) ?? [];

    if (edges.isEmpty) return _staticBanners();

    return edges
        .map((e) => HomeBanner.fromMetaobjectJson(
            e['node'] as Map<String, dynamic>))
        .toList();
  } catch (e) {
    _log('getHomeBanners EXCEPTION: $e');
    return _staticBanners();
  }
}

  List<HomeBanner> _staticBanners() => [
        const HomeBanner(
          id: 'static_1',
          imageUrl: null,
          title: 'DEFINE\nYOUR\nVIBE.',
          subtitle: 'NEW COLLECTION',
          ctaLabel: 'SHOP NOW',
        ),
      ];

  Future<List<ShopifyProduct>> getHotDeals({int first = 4}) =>
      getProductsByCollection(ShopifyConstants.hotDealsHandle, first: first);

  Future<List<ShopifyProduct>> getOversizedShirts({int first = 10}) =>
      getProductsByCollection(ShopifyConstants.oversizedShirtsHandle, first: first);
}

class BalloonBannerData {
  final String title;
  final String description;
  final String? imageUrl;

  const BalloonBannerData({
    required this.title,
    required this.description,
    this.imageUrl,
  });
}