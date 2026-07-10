import 'dart:convert';
import 'package:rookies_jeans/constant/shopify_api.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/product_detail_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/models/banner_model.dart';
import 'package:rookies_jeans/models/collection_model.dart';

class PaginatedProductsResponse {
  final List<ShopifyProduct> products;
  final bool hasNextPage;
  final String? endCursor;
  final List<ShopifyFilter> filters;

  const PaginatedProductsResponse({
    required this.products,
    required this.hasNextPage,
    required this.endCursor,
    this.filters = const [],
  });
}

enum ProductSortOption {
  featured('Featured', 'COLLECTION_DEFAULT', false),
  priceLowToHigh('Price: Low to High', 'PRICE', false),
  priceHighToLow('Price: High to Low', 'PRICE', true),
  newest('Newest', 'CREATED', true),
  bestSelling('Best Selling', 'BEST_SELLING', false),
  titleAZ('Alphabetically: A-Z', 'TITLE', false),
  titleZA('Alphabetically: Z-A', 'TITLE', true);

  final String label;
  final String shopifyKey;
  final bool reverse;

  const ProductSortOption(this.label, this.shopifyKey, this.reverse);
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

  void _log(String msg) => ShopifyGraphQL.log('ShopifyStorefrontService', msg);

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
    String sortKey = 'COLLECTION_DEFAULT',
    bool reverse = false,
    List<String> filters = const [],
  }) {
    final filterKey = filters.join('|');
    return _cachedFetch(
      'collection:$handle:$first:${after ?? ''}:$sortKey:$reverse:$filterKey',
      () => _fetchProductsByCollectionPaginated(
        handle,
        first: first,
        after: after,
        sortKey: sortKey,
        reverse: reverse,
        filters: filters,
      ),
    );
  }

  Future<PaginatedProductsResponse> _fetchProductsByCollectionPaginated(
    String handle, {
    int first = 24,
    String? after,
    String sortKey = 'COLLECTION_DEFAULT',
    bool reverse = false,
    List<String> filters = const [],
  }) async {
    const String query = r'''
    query getCollectionProducts(
      $handle: String!
      $first: Int!
      $after: String
      $sortKey: ProductCollectionSortKeys
      $reverse: Boolean
      $filters: [ProductFilter!]
    ) {
      collectionByHandle(handle: $handle) {
        products(
          first: $first
          after: $after
          sortKey: $sortKey
          reverse: $reverse
          filters: $filters
        ) {
          filters {
            id
            label
            type
            values {
              id
              label
              count
              input
            }
          }
          edges {
            cursor
            node {
              id
              title
              handle
              priceRange { minVariantPrice { amount currencyCode } }
              compareAtPriceRange { minVariantPrice { amount currencyCode } }
              images(first: 10) { edges { node { url altText } } }
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
      final decodedFilters = filters
          .map((f) {
            try {
              return jsonDecode(f) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      final res = await ShopifyGraphQL.post(
        query,
        variables: {
          'handle': handle,
          'first': first,
          'after': after,
          'sortKey': sortKey,
          'reverse': reverse,
          'filters': decodedFilters,
        },
      );

      _log(
        'getProductsByCollectionPaginated [$handle, after=$after, sort=$sortKey, reverse=$reverse, filters=$filters] → ${res.statusCode}',
      );
      final decoded = res.body;

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
      final filtersList = (productsMap?['filters'] as List?) ?? [];

      final products = edges
          .map((e) => ShopifyProduct.fromJson(e['node'] as Map<String, dynamic>))
          .toList();

      final parsedFilters = filtersList
          .map((f) => ShopifyFilter.fromJson(f as Map<String, dynamic>))
          .toList();

      return PaginatedProductsResponse(
        products: products,
        hasNextPage: pageInfo?['hasNextPage'] as bool? ?? false,
        endCursor: pageInfo?['endCursor'] as String?,
        filters: parsedFilters,
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
      final res = await ShopifyGraphQL.post(
        mutation,
        variables: {
          'input': {}
        },
      );

      _log('cartCreate → ${res.statusCode}');
      final decoded = res.body;

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
      final res = await ShopifyGraphQL.post(
        mutation,
        variables: {
          'cartId': cartId,
          'lines': [
            {
              'merchandiseId': merchandiseId,
              'quantity': quantity,
            }
          ],
        },
      );

      _log('cartLinesAdd → ${res.statusCode}');
      final decoded = res.body;

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
      final res = await ShopifyGraphQL.post(
        query,
        variables: {'handle': handle},
      );
      _log('getProductByHandle [$handle] → ${res.statusCode}');
      final decoded = res.body;
      if (decoded['errors'] != null || decoded['data'] == null) return null;
      final node = decoded['data']['productByHandle'];
      if (node == null) return null;
      return ShopifyProductDetail.fromJson(node as Map<String, dynamic>);
    } catch (e) {
      _log('getProductByHandle EXCEPTION: $e');
      return null;
    }
  }

  Future<List<ShopifyCollection>> getLatestDropCollections() => _cachedFetch(
        'latestDropCollections',
        () => _fetchCollectionTiles(
          ShopifyConstants.latestDropCollections,
          'latestDropCollections',
        ),
      );

  Future<List<ShopifyCollection>> getOurCollectionTiles() => _cachedFetch(
        'ourCollectionTiles',
        () => _fetchCollectionTiles(
          ShopifyConstants.ourCollectionTiles,
          'ourCollectionTiles',
        ),
      );

  Future<List<ShopifyCollection>> getExploreCategories() => _cachedFetch(
        'exploreCategories',
        () => _fetchCollectionTiles(
          ShopifyConstants.exploreCategories,
          'exploreCategories',
        ),
      );

  Future<List<ShopifyCollection>> _fetchCollectionTiles(
    List<Map<String, String>> tiles,
    String queryName,
  ) async {
    final buffer = StringBuffer('query $queryName {\n');
    for (int i = 0; i < tiles.length; i++) {
      buffer.write('  c$i: collectionByHandle(handle: "${tiles[i]['handle']}") {\n');
      buffer.write('    id title handle\n');
      buffer.write('    image { url altText }\n');
      buffer.write('  }\n');
    }
    buffer.write('}');

    try {
      final res = await ShopifyGraphQL.post(buffer.toString());
      _log('$queryName → ${res.statusCode}');
      if (res.errors != null || res.data == null) {
        _log('$queryName errors: ${res.errors}');
        return [];
      }
      final data = res.data!;
      final List<ShopifyCollection> result = [];
      for (int i = 0; i < tiles.length; i++) {
        final c = data['c$i'];
        if (c != null) {
          result.add(ShopifyCollection.fromJson(
            c as Map<String, dynamic>,
            label: tiles[i]['label']!,
          ));
        } else {
          _log('$queryName: no collection for handle "${tiles[i]['handle']}"');
        }
      }
      return result;
    } catch (e) {
      _log('$queryName EXCEPTION: $e');
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
      final res = await ShopifyGraphQL.post(query);
      _log('getBalloonBanner → ${res.statusCode}');
      final decoded = res.body;
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
      final res = await ShopifyGraphQL.post(query);
      _log('getHomeBanners → ${res.statusCode}');
      final decoded = res.body;

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

  Future<List<ShopifyCollection>> fetchCollectionsByHandles(
    List<Map<String, String>> items) async {
    final buffer = StringBuffer('query fetchCollections {\n');
    for (int i = 0; i < items.length; i++) {
      buffer.write('  c$i: collectionByHandle(handle: "${items[i]['handle']}") {\n');
      buffer.write('    id title handle\n');
      buffer.write('    image { url altText }\n');
      buffer.write('    products(first: 1) {\n');
      buffer.write('      edges { node { images(first: 1) { edges { node { url } } } } }\n');
      buffer.write('    }\n');
      buffer.write('  }\n');
    }
    buffer.write('}');

    try {
      final res = await ShopifyGraphQL.post(buffer.toString());
      _log('fetchCollectionsByHandles → ${res.statusCode}');
      final decoded = res.body;
      if (decoded['errors'] != null || decoded['data'] == null) return [];
      final data = decoded['data'] as Map<String, dynamic>;
      final List<ShopifyCollection> result = [];
      for (int i = 0; i < items.length; i++) {
        final c = data['c$i'];
        if (c == null) continue;

        String? imageUrl = c['image']?['url'] as String?;
        if (imageUrl == null) {
          final edges = c['products']?['edges'] as List?;
          if (edges != null && edges.isNotEmpty) {
            final imgEdges = edges[0]['node']['images']['edges'] as List?;
            if (imgEdges != null && imgEdges.isNotEmpty) {
              imageUrl = imgEdges[0]['node']['url'] as String?;
            }
          }
        }

        result.add(ShopifyCollection(
          id: c['id'] as String,
          title: c['title'] as String,
          handle: c['handle'] as String,
          imageUrl: imageUrl,
          label: items[i]['label']!,
        ));
      }
      return result;
    } catch (e) {
      _log('fetchCollectionsByHandles EXCEPTION: $e');
      return [];
    }
  }

  Future<List<ShopifyProduct>> searchProducts(
    String query, {
    int first = 20,
  }) =>
      _cachedFetch(
        'search:${query.toLowerCase()}:$first',
        () => _fetchSearchProducts(query, first: first),
      );

  Future<List<ShopifyProduct>> _fetchSearchProducts(
    String query, {
    int first = 20,
  }) async {
    const String gqlQuery = r'''
    query searchProducts($query: String!, $first: Int!) {
      products(query: $query, first: $first) {
        edges {
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
      }
    }
    ''';

    try {
      final res = await ShopifyGraphQL.post(
        gqlQuery,
        variables: {
          'query': query,
          'first': first,
        },
      );

      _log('searchProducts [$query] → ${res.statusCode}');
      final decoded = res.body;

      if (decoded['errors'] != null || decoded['data'] == null) {
        _log('searchProducts errors: ${decoded['errors']}');
        return [];
      }

      final edges =
          (decoded['data']?['products']?['edges'] as List?) ?? [];

      return edges
          .map((e) =>
              ShopifyProduct.fromJson(e['node'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('searchProducts EXCEPTION: $e');
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