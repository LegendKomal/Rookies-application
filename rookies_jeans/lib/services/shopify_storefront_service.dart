import 'dart:convert';
import 'package:rookies_jeans/constant/shopify_api.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/product_detail_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/models/banner_model.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/home_content_models.dart';
import 'package:rookies_jeans/models/shop_menu_model.dart';

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

  static const List<Map<String, String>> _variantMetafieldIdentifiers = [
    {'namespace': 'custom', 'key': 'fit'},
    {'namespace': 'custom', 'key': 'material'},
    {'namespace': 'custom', 'key': 'fabric'},
  ];

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
      getExploreCategoriesContent(),
      getPromoBlocks(),
      getShopTheLookEntries(),
      getOccasionTilesContent(),
      getInstagramPostsContent(),
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
query getProduct($handle: String!, $identifiers: [HasMetafieldsIdentifier!]!) {
  productByHandle(handle: $handle) {
    id title handle description
    vendor
    productType
    tags
    collections(first: 10) { edges { node { id } } }
    priceRange { minVariantPrice { amount currencyCode } }
    compareAtPriceRange { minVariantPrice { amount currencyCode } }
    images(first: 10) { edges { node { url altText } } }
    options {
  name
  values
  optionValues {
    name
    swatch {
      color
      image { previewImage { url } }
    }
  }
}
    variants(first: 50) {
      edges {
        node {
          id title availableForSale
          priceV2 { amount currencyCode }
          compareAtPriceV2 { amount currencyCode }
          selectedOptions { name value }
          metafields(identifiers: $identifiers) {
            namespace
            key
            value
            type
          }
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
        variables: {
          'handle': handle,
          'identifiers': _variantMetafieldIdentifiers, // NEW
        },
      );
      _log('getProductByHandle [$handle] → ${res.statusCode}');
      final decoded = res.body;
      if (decoded['errors'] != null || decoded['data'] == null) return null;
      final node = decoded['data']['productByHandle'];
      _log('RAW options: ${node['options']}');
final rawVariantEdges = (node['variants']?['edges'] as List?) ?? [];
_log('RAW variant count: ${rawVariantEdges.length}');
for (final e in rawVariantEdges) {
  final v = e['node'];
  _log('RAW variant: id=${v['id']} title=${v['title']} selectedOptions=${v['selectedOptions']}');
}

      if (node == null) return null;
      return ShopifyProductDetail.fromJson(node as Map<String, dynamic>);
    } catch (e) {
      _log('getProductByHandle EXCEPTION: $e');
      return null;
    }
  }

  /// Fetches the sibling products in the same Variant King / SA Variants
  /// color group as [handle] (metafield `vkcl.group_data` on the Product).
  /// Returns an empty list if the product has no group, or the metafield
  /// isn't present. The current product's own handle is excluded from the
  /// result — this is *other* colors only.
  Future<List<ShopifyProduct>> getColorGroupSiblings(String handle) =>
      _cachedFetch(
        'colorSiblings:$handle',
        () => _fetchColorGroupSiblings(handle),
      );

  Future<List<ShopifyProduct>> _fetchColorGroupSiblings(String handle) async {
    const String groupQuery = r'''
    query getGroupData($handle: String!) {
      productByHandle(handle: $handle) {
        groupData: metafield(namespace: "vkcl", key: "group_data") {
          value
        }
      }
    }
    ''';

    try {
      final res = await ShopifyGraphQL.post(
        groupQuery,
        variables: {'handle': handle},
      );
      _log('getColorGroupSiblings [$handle] → ${res.statusCode}');
      final decoded = res.body;

      if (decoded['errors'] != null || decoded['data'] == null) {
        _log('getColorGroupSiblings errors: ${decoded['errors']}');
        return [];
      }

      final rawValue =
          decoded['data']['productByHandle']?['groupData']?['value']
              as String?;
      if (rawValue == null || rawValue.isEmpty) {
        // No color group on this product — perfectly normal.
        return [];
      }

      final parsed = jsonDecode(rawValue);
      if (parsed is! List || parsed.isEmpty) return [];

      // The app writes one group per product; take the first entry.
      final group = ColorGroup.fromJson(parsed.first as Map<String, dynamic>);

      final siblingHandles = group.products
          .map((p) => p.handle)
          .where((h) => h.isNotEmpty && h != handle)
          .toSet()
          .toList();

      if (siblingHandles.isEmpty) return [];

      return _fetchProductsByHandles(siblingHandles);
    } catch (e) {
      _log('_fetchColorGroupSiblings EXCEPTION: $e');
      return [];
    }
  }

  /// Batches a lightweight fetch (title, image, price, options/variants)
  /// for several products by handle in a single aliased GraphQL request —
  /// same pattern as [_fetchCollectionTiles] below.
  Future<List<ShopifyProduct>> _fetchProductsByHandles(
    List<String> handles,
  ) async {
    final buffer = StringBuffer('query getProductsByHandles {\n');
    for (int i = 0; i < handles.length; i++) {
      final safeHandle = handles[i].replaceAll('"', r'\"');
      buffer.write('  p$i: productByHandle(handle: "$safeHandle") {\n');
      buffer.write('    id title handle\n');
      buffer.write(
          '    priceRange { minVariantPrice { amount currencyCode } }\n');
      buffer.write(
          '    compareAtPriceRange { minVariantPrice { amount currencyCode } }\n');
      buffer.write('    images(first: 1) { edges { node { url altText } } }\n');
      buffer.write(
          '    options { name values optionValues { name swatch { color } } }\n');
      buffer.write('    variants(first: 10) {\n');
      buffer.write(
          '      edges { node { id title availableForSale selectedOptions { name value } } }\n');
      buffer.write('    }\n');
      buffer.write('  }\n');
    }
    buffer.write('}');

    try {
      final res = await ShopifyGraphQL.post(buffer.toString());
      _log('_fetchProductsByHandles [$handles] → ${res.statusCode}');
      final decoded = res.body;
      if (decoded['errors'] != null || decoded['data'] == null) {
        _log('_fetchProductsByHandles errors: ${decoded['errors']}');
        return [];
      }

      final data = decoded['data'] as Map<String, dynamic>;
      final products = <ShopifyProduct>[];
      for (int i = 0; i < handles.length; i++) {
        final node = data['p$i'];
        if (node != null) {
          products.add(ShopifyProduct.fromJson(node as Map<String, dynamic>));
        }
      }
      return products;
    } catch (e) {
      _log('_fetchProductsByHandles EXCEPTION: $e');
      return [];
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

  /// Scopes the search to the product title instead of Shopify's default
  /// cross-field match (title, tags, product type, vendor, description),
  /// which otherwise surfaces unrelated items — e.g. a "shirt" search
  /// returning polo tees tagged/categorized as "Shirts" in the catalog.
  String _titleScopedQuery(String raw) {
    final words = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.replaceAll('"', ''));
    if (words.isEmpty) return raw;
    return words.map((w) => 'title:*$w*').join(' AND ');
  }

  Future<PaginatedProductsResponse> searchProductsPaginated(
    String query, {
    int first = 24,
    String? after,
    String sortKey = 'RELEVANCE',
    bool reverse = false,
    double? minPrice,
    double? maxPrice,
    List<String> filters = const [],
  }) {
    final filterKey = filters.join('|');
    final key =
        'searchPaged:${query.toLowerCase()}:$first:${after ?? ''}:$sortKey:$reverse:$minPrice:$maxPrice:$filterKey';
    return _cachedFetch(
      key,
      () => _fetchSearchProductsPaginated(
        query,
        first: first,
        after: after,
        sortKey: sortKey,
        reverse: reverse,
        minPrice: minPrice,
        maxPrice: maxPrice,
        filters: filters,
      ),
    );
  }

  /// The root `search` field only understands plain search terms — it does
  /// NOT support `products(query:)` syntax like `title:*shirt*` or
  /// `variants.price:>=X`. Sending that syntax makes Shopify ignore the
  /// terms and match the whole catalog, so every search returned the same
  /// results. Pass the user's text as-is; Shopify matches it against title,
  /// tags, product type, vendor and variant options (e.g. colors) and ranks
  /// by relevance.
  String _searchQueryString(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Shopify's `search` pads relevance results with loosely related items
  /// (e.g. "black shirt" → 663 hits, only ~70 actually black shirts, spread
  /// across the whole list). Keep a product only when every search word
  /// starts a word in its title, product type, tags or option values (so a
  /// color search also finds products whose color lives in the Color
  /// option). Matching at word starts (hyphens count as part of a word)
  /// keeps "shirt" from matching tees via "TSHIRTS" or a "T-SHIRT" tag.
  bool _matchesSearchWords(Map<String, dynamic> node, List<RegExp> words) {
    if (words.isEmpty) return true;
    final haystack = [
      node['title'],
      node['productType'],
      ...((node['tags'] as List?) ?? const []),
      for (final opt in (node['options'] as List?) ?? const [])
        ...(((opt as Map)['values'] as List?) ?? const []),
    ].whereType<String>().join(' ');
    return words.every((w) => w.hasMatch(haystack));
  }

  List<RegExp> _searchWordPatterns(String raw) => raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => RegExp(
            '(^|[^a-z0-9-])${RegExp.escape(w)}',
            caseSensitive: false,
          ))
      .toList();

  // Raw page size pulled from Shopify per request while collecting filtered
  // matches — larger than a UI page so sparse queries need fewer round trips.
  static const int _kSearchScanPageSize = 100;

  Future<PaginatedProductsResponse> _fetchSearchProductsPaginated(
    String query, {
    int first = 24,
    String? after,
    String sortKey = 'RELEVANCE',
    bool reverse = false,
    double? minPrice,
    double? maxPrice,
    List<String> filters = const [],
  }) async {
    // Uses the root `search` field rather than `products`: `products(query:)`
    // never computes facets (its `filters` connection field is always empty),
    // while `search` supports both `productFilters` (server-side filtering)
    // and returns real facet counts, matching collection browsing behavior.
    // Trade-off: SearchSortKeys only defines RELEVANCE and PRICE, so callers
    // must restrict sortKey to one of those while in search mode.
    const String gqlQuery = r'''
    query searchProductsPaginated(
      $query: String!
      $first: Int!
      $after: String
      $sortKey: SearchSortKeys
      $reverse: Boolean
      $productFilters: [ProductFilter!]
    ) {
      search(
        query: $query
        first: $first
        after: $after
        sortKey: $sortKey
        reverse: $reverse
        types: [PRODUCT]
        prefix: LAST
        productFilters: $productFilters
      ) {
        productFilters {
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
            ... on Product {
              id
              title
              handle
              createdAt
              productType
              tags
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
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
    ''';

    const empty = PaginatedProductsResponse(
      products: [],
      hasNextPage: false,
      endCursor: null,
    );

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

      // Price bounds go through productFilters since `search` has no
      // query-string syntax for them.
      if (minPrice != null || maxPrice != null) {
        decodedFilters.add({
          'price': {
            'min': ?minPrice,
            'max': ?maxPrice,
          },
        });
      }

      final words = _searchWordPatterns(query);
      final products = <ShopifyProduct>[];
      List<ShopifyFilter>? parsedFilters;
      String? cursor = after;
      bool hasNextPage = true;

      // Keep scanning raw pages until we've collected at least `first` real
      // matches or Shopify runs out, so a page of mostly-unrelated padding
      // never comes back empty and stalls infinite scroll. Whole raw pages
      // are consumed, so the returned cursor never skips a match.
      while (products.length < first && hasNextPage) {
        final res = await ShopifyGraphQL.post(
          gqlQuery,
          variables: {
            'query': _searchQueryString(query),
            'first': _kSearchScanPageSize,
            'after': cursor,
            'sortKey': sortKey,
            'reverse': reverse,
            'productFilters': decodedFilters,
          },
        );

        _log(
          'searchProductsPaginated [$query, after=$cursor, sort=$sortKey, reverse=$reverse, filters=$filters] → ${res.statusCode}',
        );
        final decoded = res.body;

        if (decoded['errors'] != null || decoded['data'] == null) {
          _log('searchProductsPaginated errors: ${decoded['errors']}');
          if (products.isEmpty) return empty;
          break;
        }

        final searchMap = decoded['data']?['search'] as Map<String, dynamic>?;
        final edges = (searchMap?['edges'] as List?) ?? [];
        final pageInfo = searchMap?['pageInfo'] as Map<String, dynamic>?;

        parsedFilters ??= ((searchMap?['productFilters'] as List?) ?? [])
            .map((f) => ShopifyFilter.fromJson(f as Map<String, dynamic>))
            .toList();

        products.addAll(edges
            .map((e) => e['node'] as Map<String, dynamic>?)
            .where((node) =>
                node != null &&
                node.isNotEmpty &&
                _matchesSearchWords(node, words))
            .map((node) => ShopifyProduct.fromJson(node!)));

        hasNextPage = pageInfo?['hasNextPage'] as bool? ?? false;
        cursor = pageInfo?['endCursor'] as String?;
      }

      return PaginatedProductsResponse(
        products: products,
        hasNextPage: hasNextPage,
        endCursor: cursor,
        filters: parsedFilters ?? const [],
      );
    } catch (e) {
      _log('searchProductsPaginated EXCEPTION: $e');
      return empty;
    }
  }

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
          'query': _titleScopedQuery(query),
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

  Future<List<PromoBlockContent>> getPromoBlocks() =>
      _cachedFetch('promoBlocks', _fetchPromoBlocks);

  Future<List<PromoBlockContent>> _fetchPromoBlocks() async {
    const String query = r'''
      query getPromoBlocks {
        metaobjects(type: "promo_block", first: 20) {
          edges {
            node {
              id
              image: field(key: "image") { reference { ... on MediaImage { image { url } } } }
              label: field(key: "label") { value }
              button_label: field(key: "button_label") { value }
              collection_handle: field(key: "collection_handle") { value }
              sort_order: field(key: "sort_order") { value }
            }
          }
        }
      }
    ''';

    try {
      final res = await ShopifyGraphQL.post(query);
      _log('getPromoBlocks → ${res.statusCode}');
      if (res.hasErrors || res.data == null) return [];

      final edges = (res.data!['metaobjects']['edges'] as List?) ?? [];
      final blocks = edges
          .map((e) =>
              PromoBlockContent.fromMetaobjectJson(e['node'] as Map<String, dynamic>))
          .toList();
      blocks.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return blocks;
    } catch (e) {
      _log('getPromoBlocks EXCEPTION: $e');
      return [];
    }
  }

  Future<List<ShopTheLookEntry>> getShopTheLookEntries() =>
      _cachedFetch('shopTheLookEntries', _fetchShopTheLookEntries);

  Future<List<ShopTheLookEntry>> _fetchShopTheLookEntries() async {
    const String query = r'''
      query getShopTheLook {
        metaobjects(type: "shop_the_look", first: 20) {
          edges {
            node {
              id
              image: field(key: "image") { reference { ... on MediaImage { image { url } } } }
              sort_order: field(key: "sort_order") { value }
              products: field(key: "products") {
                references(first: 6) {
                  edges {
                    node {
                      ... on Product {
                        id
                        title
                        handle
                        priceRange { minVariantPrice { amount currencyCode } }
                        compareAtPriceRange { minVariantPrice { amount currencyCode } }
                        images(first: 4) { edges { node { url altText } } }
                        options { name values optionValues { name swatch { color } } }
                        variants(first: 10) {
                          edges { node { id title availableForSale selectedOptions { name value } } }
                        }
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
      final res = await ShopifyGraphQL.post(query);
      _log('getShopTheLookEntries → ${res.statusCode}');
      if (res.hasErrors || res.data == null) return [];

      final edges = (res.data!['metaobjects']['edges'] as List?) ?? [];
      final entries = edges
          .map((e) =>
              ShopTheLookEntry.fromMetaobjectJson(e['node'] as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return entries;
    } catch (e) {
      _log('getShopTheLookEntries EXCEPTION: $e');
      return [];
    }
  }

  Future<List<OccasionTileContent>> getOccasionTilesContent() =>
      _cachedFetch('occasionTiles', _fetchOccasionTiles);

  Future<List<OccasionTileContent>> _fetchOccasionTiles() async {
    const String query = r'''
      query getOccasionTiles {
        metaobjects(type: "occasion_tile", first: 20) {
          edges {
            node {
              id
              image: field(key: "image") { reference { ... on MediaImage { image { url } } } }
              label: field(key: "label") { value }
              collection_handle: field(key: "collection_handle") { value }
              sort_order: field(key: "sort_order") { value }
            }
          }
        }
      }
    ''';

    try {
      final res = await ShopifyGraphQL.post(query);
      _log('getOccasionTilesContent → ${res.statusCode}');
      if (res.hasErrors || res.data == null) return [];

      final edges = (res.data!['metaobjects']['edges'] as List?) ?? [];
      final tiles = edges
          .map((e) => OccasionTileContent.fromMetaobjectJson(
              e['node'] as Map<String, dynamic>))
          .toList();
      tiles.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return tiles;
    } catch (e) {
      _log('getOccasionTilesContent EXCEPTION: $e');
      return [];
    }
  }

  Future<List<ExploreCategoryContent>> getExploreCategoriesContent() =>
      _cachedFetch('exploreCategoriesContent', _fetchExploreCategoriesContent);

  Future<List<ExploreCategoryContent>> _fetchExploreCategoriesContent() async {
    const String query = r'''
      query getExploreCategories {
        metaobjects(type: "explore_category", first: 30) {
          edges {
            node {
              id
              image: field(key: "image") { reference { ... on MediaImage { image { url } } } }
              label: field(key: "label") { value }
              collection_handle: field(key: "collection_handle") { value }
              section: field(key: "section") { value }
              sort_order: field(key: "sort_order") { value }
            }
          }
        }
      }
    ''';

    try {
      final res = await ShopifyGraphQL.post(query);
      _log('getExploreCategoriesContent → ${res.statusCode}');
      if (res.hasErrors || res.data == null) return [];

      final edges = (res.data!['metaobjects']['edges'] as List?) ?? [];
      final categories = edges
          .map((e) => ExploreCategoryContent.fromMetaobjectJson(
              e['node'] as Map<String, dynamic>))
          .toList();
      categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return categories;
    } catch (e) {
      _log('getExploreCategoriesContent EXCEPTION: $e');
      return [];
    }
  }

  /// The "Explore Categories" accordion's Top Wear / Bottom Wear grouping
  /// is pinned in [ShopifyConstants.exploreMenuSections] (see that constant
  /// for why — Shopify's own `top-wear`/`bottom-wear` navigation menus
  /// don't match the intended design, and the Storefront API can't list
  /// every menu handle in the shop to auto-discover the right ones). What
  /// *is* fetched live here is each category's fits: Shopify Admin →
  /// Content → Menus has one flat menu per category, handled the same as
  /// the category itself (e.g. `shirts`), and its items become that
  /// category's fit list.
  Future<List<ShopMenuSection>> getExploreMenuSections() => _cachedFetch(
        'exploreMenuSections',
        _fetchExploreMenuSections,
      );

  Future<List<ShopMenuSection>> _fetchExploreMenuSections() async {
    final sectionDefs = ShopifyConstants.exploreMenuSections;
    final allHandles = <String>{
      for (final section in sectionDefs)
        for (final category in section['categories'] as List)
          (category as Map)['handle'] as String,
    }.toList();

    final fitsByHandle = await _fetchFitMenusByHandle(allHandles);

    return sectionDefs.map((section) {
      final categories = (section['categories'] as List).map((raw) {
        final category = raw as Map;
        final handle = category['handle'] as String;
        return ShopMenuCategory(
          title: category['title'] as String,
          collectionHandle: handle,
          fits: fitsByHandle[handle] ?? const [],
        );
      }).toList();

      final title = section['title'] as String;
      return ShopMenuSection(
        title: title,
        handle: title.toLowerCase().replaceAll(' ', '-'),
        categories: categories,
      );
    }).toList();
  }

  /// Batch-fetches one flat menu per handle in [handles] (each menu's items
  /// become that category's fits) using a single aliased GraphQL request. A
  /// handle with no matching menu is simply omitted from the result.
  Future<Map<String, List<ShopMenuFit>>> _fetchFitMenusByHandle(
    List<String> handles,
  ) async {
    if (handles.isEmpty) return {};

    final buffer = StringBuffer('query getFitMenus {\n');
    for (int i = 0; i < handles.length; i++) {
      final safeHandle = handles[i].replaceAll('"', r'\"');
      buffer.write('  f$i: menu(handle: "$safeHandle") {\n');
      buffer.write('    items { title url }\n');
      buffer.write('  }\n');
    }
    buffer.write('}');

    try {
      final res = await ShopifyGraphQL.post(buffer.toString());
      _log('getExploreMenuSections (fits) [$handles] → ${res.statusCode}');
      if (res.hasErrors || res.data == null) return {};

      final data = res.data!;
      final Map<String, List<ShopMenuFit>> result = {};
      for (int i = 0; i < handles.length; i++) {
        final node = data['f$i'] as Map<String, dynamic>?;
        if (node == null) continue;
        final items = ((node['items'] as List?) ?? [])
            .map((e) {
              final fit = e as Map<String, dynamic>;
              return ShopMenuFit(
                title: fit['title'] as String? ?? '',
                url: fit['url'] as String? ?? '',
              );
            })
            .toList();
        result[handles[i]] = items;
      }
      return result;
    } catch (e) {
      _log('_fetchFitMenusByHandle EXCEPTION: $e');
      return {};
    }
  }

  /// Every collection in the store, for the "Collections" page. Unlike
  /// [getExploreCategories]/[getOurCollectionTiles] (which are curated,
  /// hand-picked lists), this is the full catalog of collections as
  /// configured in Shopify.
  Future<List<ShopifyCollection>> getAllCollections({int first = 100}) =>
      _cachedFetch(
        'allCollections:$first',
        () => _fetchAllCollections(first),
      );

  Future<List<ShopifyCollection>> _fetchAllCollections(int first) async {
    const String query = r'''
      query getAllCollections($first: Int!) {
        collections(first: $first, sortKey: TITLE) {
          edges {
            node {
              id
              title
              handle
              image { url altText }
            }
          }
        }
      }
    ''';

    try {
      final res =
          await ShopifyGraphQL.post(query, variables: {'first': first});
      _log('getAllCollections → ${res.statusCode}');
      if (res.hasErrors || res.data == null) {
        _log('getAllCollections errors: ${res.errors}');
        return [];
      }

      final edges = (res.data!['collections']?['edges'] as List?) ?? [];
      return edges.map((e) {
        final node = e['node'] as Map<String, dynamic>;
        return ShopifyCollection.fromJson(
          node,
          label: (node['title'] as String? ?? '').toUpperCase(),
        );
      }).toList();
    } catch (e) {
      _log('getAllCollections EXCEPTION: $e');
      return [];
    }
  }

  Future<List<InstagramPostContent>> getInstagramPostsContent() =>
      _cachedFetch('instagramPosts', _fetchInstagramPosts);

  Future<List<InstagramPostContent>> _fetchInstagramPosts() async {
    const String query = r'''
      query getInstagramPosts {
        metaobjects(type: "instagram_post", first: 20) {
          edges {
            node {
              id
              image: field(key: "image") { reference { ... on MediaImage { image { url } } } }
              post_url: field(key: "post_url") { value }
              username: field(key: "username") { value }
              sort_order: field(key: "sort_order") { value }
            }
          }
        }
      }
    ''';

    try {
      final res = await ShopifyGraphQL.post(query);
      _log('getInstagramPostsContent → ${res.statusCode}');
      if (res.hasErrors || res.data == null) return [];

      final edges = (res.data!['metaobjects']['edges'] as List?) ?? [];
      final posts = edges
          .map((e) => InstagramPostContent.fromMetaobjectJson(
              e['node'] as Map<String, dynamic>))
          .toList();
      posts.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return posts;
    } catch (e) {
      _log('getInstagramPostsContent EXCEPTION: $e');
      return [];
    }
  }

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