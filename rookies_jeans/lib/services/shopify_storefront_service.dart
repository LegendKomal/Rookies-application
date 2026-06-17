import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/product_detail_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/models/banner_model.dart';
import 'package:rookies_jeans/models/collection_model.dart';

class PaginatedProductsResponse {
  final List<ShopifyProduct> products;
  final bool hasNextPage;
  final String? endCursor;

  const PaginatedProductsResponse({
    required this.products,
    required this.hasNextPage,
    required this.endCursor,
  });
}

class ShopifyStorefrontService {
  ShopifyStorefrontService._();
  static final ShopifyStorefrontService instance = ShopifyStorefrontService._();

  final Map<String, dynamic> _cache = {};
  final Map<String, Future<dynamic>> _inFlight = {};

  String? _cartId;

  void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[ShopifyStorefrontService] $msg');
  }

  Future<T> _cachedFetch<T>(
    String cacheKey,
    Future<T> Function() fetcher,
  ) async {
    if (_cache.containsKey(cacheKey)) {
      _log('cache HIT: $cacheKey');
      return _cache[cacheKey] as T;
    }

    if (_inFlight.containsKey(cacheKey)) {
      _log('in-flight HIT: $cacheKey');
      return (await _inFlight[cacheKey]) as T;
    }

    final future = fetcher();
    _inFlight[cacheKey] = future;

    try {
      final result = await future;
      _cache[cacheKey] = result;
      return result;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<void> prefetchHomeData() async {
    await Future.wait([
      getHomeBanners(),
      getHotDeals(),
      getOversizedShirts(),
      getBalloonBanner(),
      getLatestDropCollections(),
      getOurCollectionTiles(),
    ]);
  }

  Future<List<ShopifyProduct>> getProductsByCollection(
    String handle, {
    int first = 24,
  }) async {
    final response = await getProductsByCollectionPaginated(
      handle,
      first: first,
    );
    return response.products;
  }

  Future<PaginatedProductsResponse> getProductsByCollectionPaginated(
    String handle, {
    int first = 24,
    String? after,
  }) =>
      _cachedFetch(
        'collection:$handle:$first:${after ?? ''}',
        () => _fetchProductsByCollectionPaginated(
          handle,
          first: first,
          after: after,
        ),
      );

  Future<PaginatedProductsResponse> _fetchProductsByCollectionPaginated(
    String handle, {
    int first = 24,
    String? after,
  }) async {
    const String query = r'''
    query getCollectionProducts($handle: String!, $first: Int!, $after: String) {
      collectionByHandle(handle: $handle) {
        products(first: $first, after: $after) {
          edges {
            cursor
            node {
              id
              title
              handle
              priceRange { minVariantPrice { amount currencyCode } }
              compareAtPriceRange { minVariantPrice { amount currencyCode } }
              images(first: 2) { edges { node { url altText } } }
              options {
                name
                values
                optionValues { name swatch { color } }
              }
              variants(first: 10) {
                edges {
                  node {
                    id
                    title
                    availableForSale
                    selectedOptions { name value }
                  }
                }
              }
            }
          }
          pageInfo {
            hasNextPage
            endCursor
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
          'variables': {
            'handle': handle,
            'first': first,
            'after': after,
          },
        }),
      );

      _log('getProductsByCollectionPaginated [$handle, after=$after] → ${response.statusCode}');
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (decoded['errors'] != null) {
        _log('errors: ${decoded['errors']}');
        return const PaginatedProductsResponse(
          products: [],
          hasNextPage: false,
          endCursor: null,
        );
      }

      final collection = decoded['data']?['collectionByHandle'];
      if (collection == null) {
        return const PaginatedProductsResponse(
          products: [],
          hasNextPage: false,
          endCursor: null,
        );
      }

      final productsMap = collection['products'] as Map<String, dynamic>?;
      final edges = (productsMap?['edges'] as List?) ?? [];
      final pageInfo = productsMap?['pageInfo'] as Map<String, dynamic>?;

      final products = edges
          .map((e) => ShopifyProduct.fromJson(e['node'] as Map<String, dynamic>))
          .toList();

      return PaginatedProductsResponse(
        products: products,
        hasNextPage: pageInfo?['hasNextPage'] as bool? ?? false,
        endCursor: pageInfo?['endCursor'] as String?,
      );
    } catch (e) {
      _log('EXCEPTION in _fetchProductsByCollectionPaginated: $e');
      return const PaginatedProductsResponse(
        products: [],
        hasNextPage: false,
        endCursor: null,
      );
    }
  }

  Future<bool> addProductToCart(ShopifyProduct product, {int quantity = 1}) async {
  try {
    if (product.variants.isEmpty) {
      _log('addProductToCart: no variants found for ${product.title}');
      return false;
    }

    final variantId = product.variants.first.id;

    if (_cartId == null) {
      _cartId = await _createCart();
      if (_cartId == null) return false;
    }

    final result = await _addCartLine(
      cartId: _cartId!,
      merchandiseId: variantId,
      quantity: quantity,
    );

    return result;
  } catch (e) {
    _log('addProductToCart EXCEPTION: $e');
    return false;
  }
}

  Future<String?> _createCart() async {
    const String mutation = r'''
    mutation cartCreate($input: CartInput) {
      cartCreate(input: $input) {
        cart {
          id
        }
        userErrors {
          field
          message
        }
      }
    }
    ''';

    try {
      final response = await http.post(
        Uri.parse(ShopifyConstants.storefrontEndpoint),
        headers: ShopifyConstants.headers,
        body: jsonEncode({
          'query': mutation,
          'variables': {
            'input': {}
          },
        }),
      );

      _log('cartCreate → ${response.statusCode}');
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (decoded['errors'] != null) {
        _log('cartCreate errors: ${decoded['errors']}');
        return null;
      }

      final data = decoded['data']?['cartCreate'];
      final userErrors = (data?['userErrors'] as List?) ?? [];
      if (userErrors.isNotEmpty) {
        _log('cartCreate userErrors: $userErrors');
        return null;
      }

      return data?['cart']?['id'] as String?;
    } catch (e) {
      _log('_createCart EXCEPTION: $e');
      return null;
    }
  }

  Future<bool> _addCartLine({
  required String cartId,
  required String merchandiseId,
  required int quantity,
}) async {
  const String mutation = r'''
  mutation cartLinesAdd($cartId: ID!, $lines: [CartLineInput!]!) {
    cartLinesAdd(cartId: $cartId, lines: $lines) {
      cart {
        id
        totalQuantity
      }
      userErrors {
        field
        message
      }
    }
  }
  ''';

  try {
    final response = await http.post(
      Uri.parse(ShopifyConstants.storefrontEndpoint),
      headers: ShopifyConstants.headers,
      body: jsonEncode({
        'query': mutation,
        'variables': {
          'cartId': cartId,
          'lines': [
            {
              'merchandiseId': merchandiseId,
              'quantity': quantity,
            }
          ],
        },
      }),
    );

    _log('cartLinesAdd → ${response.statusCode}');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (decoded['errors'] != null) {
      _log('cartLinesAdd errors: ${decoded['errors']}');
      return false;
    }

    final data = decoded['data']?['cartLinesAdd'] as Map<String, dynamic>?;

    final userErrors = (data?['userErrors'] as List?) ?? [];
    if (userErrors.isNotEmpty) {
      _log('cartLinesAdd userErrors: $userErrors');
      return false;
    }

    final cart = data?['cart'];
    return cart != null;
  } catch (e) {
    _log('_addCartLine EXCEPTION: $e');
    return false;
  }
}

  Future<ShopifyProductDetail?> getProductByHandle(String handle) =>
      _cachedFetch(
        'product:$handle',
        () => _fetchProductByHandle(handle),
      );

  Future<ShopifyProductDetail?> _fetchProductByHandle(String handle) async {
    const String query = r'''
query getProduct($handle: String!) {
  productByHandle(handle: $handle) {
    id title handle description
    priceRange { minVariantPrice { amount currencyCode } }
    compareAtPriceRange { minVariantPrice { amount currencyCode } }
    images(first: 10) { edges { node { url altText } } }
    options { name values }
    variants(first: 50) {
      edges {
        node {
          id title availableForSale
          priceV2 { amount currencyCode }
          compareAtPriceV2 { amount currencyCode }
          selectedOptions { name value }
        }
      }
    }
    shippingInfo: metafield(namespace: "custom", key: "shipping_info") { value }
    careInstructions: metafield(namespace: "custom", key: "care_instructions") { value }
  }
}
''';

    try {
      final response = await http.post(
        Uri.parse(ShopifyConstants.storefrontEndpoint),
        headers: ShopifyConstants.headers,
        body: jsonEncode({
          'query': query,
          'variables': {'handle': handle},
        }),
      );
      _log('getProductByHandle [$handle] → ${response.statusCode}');
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['errors'] != null || decoded['data'] == null) return null;
      final node = decoded['data']['productByHandle'];
      if (node == null) return null;
      return ShopifyProductDetail.fromJson(node as Map<String, dynamic>);
    } catch (e) {
      _log('getProductByHandle EXCEPTION: $e');
      return null;
    }
  }

  Future<List<ShopifyCollection>> getLatestDropCollections() =>
      _cachedFetch('latestDropCollections', _fetchLatestDropCollections);

  Future<List<ShopifyCollection>> _fetchLatestDropCollections() async {
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

  Future<List<ShopifyCollection>> getOurCollectionTiles() =>
      _cachedFetch('ourCollectionTiles', _fetchOurCollectionTiles);

  Future<List<ShopifyCollection>> _fetchOurCollectionTiles() async {
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

  Future<BalloonBannerData?> getBalloonBanner() =>
      _cachedFetch('balloonBanner', _fetchBalloonBanner);

  Future<BalloonBannerData?> _fetchBalloonBanner() async {
    const String query = r'''
      query getBalloonBanner {
        collection: collectionByHandle(handle: "balloonfit-cargo") {
          title description
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

  Future<List<HomeBanner>> getHomeBanners() =>
      _cachedFetch('homeBanners', _fetchHomeBanners);

  Future<List<HomeBanner>> _fetchHomeBanners() async {
    const String query = r'''
      query getHomeBanners {
        metaobjects(type: "home_banner", first: 10) {
          edges {
            node {
              id
              fields {
                key value
                reference {
                  ... on MediaImage { image { url } }
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

      final edges = (decoded['data']['metaobjects']['edges'] as List?) ?? [];
      if (edges.isEmpty) return _staticBanners();

      return edges
          .map((e) => HomeBanner.fromMetaobjectJson(
                e['node'] as Map<String, dynamic>,
              ))
          .toList();
    } catch (e) {
      _log('getHomeBanners EXCEPTION: $e');
      return _staticBanners();
    }
  }

  Future<List<ShopifyCollection>> getExploreCategories() =>
      _cachedFetch('exploreCategories', _fetchExploreCategories);

  Future<List<ShopifyCollection>> _fetchExploreCategories() async {
    final tiles = ShopifyConstants.exploreCategories;
    final buffer = StringBuffer('query exploreCategories {\n');
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
      _log('getExploreCategories → ${response.statusCode}');
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['errors'] != null || decoded['data'] == null) {
        _log('getExploreCategories errors: ${decoded['errors']}');
        return [];
      }
      final data = decoded['data'] as Map<String, dynamic>;
      final List<ShopifyCollection> result = [];
      for (int i = 0; i < tiles.length; i++) {
        final c = data['c$i'];
        if (c != null) {
          result.add(ShopifyCollection.fromJson(
            c as Map<String, dynamic>,
            label: tiles[i]['label']!,
          ));
        } else {
          _log('getExploreCategories: no collection for handle "${tiles[i]['handle']}"');
        }
      }
      return result;
    } catch (e) {
      _log('getExploreCategories EXCEPTION: $e');
      return [];
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

  Future<List<ShopifyProduct>> getHotDeals({
    int first = ShopifyConstants.hotDealsCount,
  }) =>
      getProductsByCollection(
        ShopifyConstants.hotDealsHandle,
        first: first,
      );

  Future<List<ShopifyProduct>> getOversizedShirts({
    int first = ShopifyConstants.oversizedShirtsCount,
  }) =>
      getProductsByCollection(
        ShopifyConstants.oversizedShirtsHandle,
        first: first,
      );
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