import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/banner_model.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/home_screen_data.dart';
import 'package:rookies_jeans/models/product_model.dart';

class HomeSectionHandles {
  static const String promoBannerCollection = 'summer-banner';
  static const String oversizedShirtCollection = 'oversized-shirts';
  static const List<String> hotDealCollections = [
    'styles-under-999',
    'styles-under-1999',
    'styles-under-1599',
  ];
  static const List<String> selectedCollections = [
    'summer-edit',
    'hot-deals',
    'trending-now',
  ];
  static const List<String> selectedCategories = [
    'cargos',
    'jeans',
    'shirts',
    'TSHIRTS',
    'linens',
    'shorts',
  ];
}

class ShopifyStorefrontService {
  ShopifyStorefrontService._();

  static final ShopifyStorefrontService instance =
      ShopifyStorefrontService._();

  Future<Map<String, dynamic>> _query(String query) async {
    final response = await http.post(
      Uri.parse(ShopifyConstants.storefrontEndpoint),
      headers: ShopifyConstants.headers,
      body: jsonEncode({'query': query}),
    );

    if (response.statusCode != 200) {
      throw Exception('Shopify API error: ${response.statusCode}');
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (data['errors'] != null) {
      throw Exception('Shopify GraphQL error: ${data['errors']}');
    }

    return data;
  }

  Future<List<BannerModel>> fetchBanners() async {
    const query = '''
    {
      metaobjects(type: "banner_slide", first: 10) {
        nodes {
          fields {
            key
            value
            reference {
              ... on MediaImage {
                image {
                  url
                }
              }
            }
          }
        }
      }
    }
    ''';

    final data = await _query(query);
    final nodes = data['data']?['metaobjects']?['nodes'] as List? ?? [];

    return nodes
    .map((e) => BannerModel.fromJson(Map<String, dynamic>.from(e as Map)))
    .where(
      (e) => e.desktopImageUrl.isNotEmpty || e.mobileImageUrl.isNotEmpty,
    )
    .toList();
  }

  Future<CollectionModel?> fetchCollectionByHandle(String handle) async {
    final query = '''
    {
      collectionByHandle(handle: "$handle") {
        id
        title
        handle
        description
        image {
          url
        }
      }
    }
    ''';

    final data = await _query(query);
    final node = data['data']?['collectionByHandle'];
    if (node == null) {
      return null;
    }
    return CollectionModel.fromJson(Map<String, dynamic>.from(node as Map));
  }

  Future<List<CollectionModel>> fetchCollectionsByHandles(
    List<String> handles,
  ) async {
    final results = await Future.wait(handles.map(fetchCollectionByHandle));
    return results.whereType<CollectionModel>().toList();
  }

  Future<List<ProductModel>> fetchLatestProducts() async {
    const query = '''
    {
      products(first: 12, sortKey: CREATED_AT, reverse: true) {
        nodes {
          id
          title
          handle
          featuredImage {
  url(transform: { maxWidth: 600, maxHeight: 800 })
}
          priceRange {
            minVariantPrice {
              amount
              currencyCode
            }
          }
          compareAtPriceRange {
            minVariantPrice {
              amount
              currencyCode
            }
          }
        }
      }
    }
    ''';

    final data = await _query(query);
    final nodes = data['data']?['products']?['nodes'] as List? ?? [];
    return nodes
    .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)))
    .toList();
  }

  Future<List<ProductModel>> fetchProductsByCollection({
    required String handle,
    int first = 10,
  }) async {
    final query = '''
    {
      collectionByHandle(handle: "$handle") {
        products(first: $first) {
          nodes {
            id
            title
            handle
            featuredImage {
  url(transform: { maxWidth: 600, maxHeight: 800 })
}
            priceRange {
              minVariantPrice {
                amount
                currencyCode
              }
            }
            compareAtPriceRange {
              minVariantPrice {
                amount
                currencyCode
              }
            }
          }
        }
      }
    }
    ''';

    final data = await _query(query);
    final nodes =
        data['data']?['collectionByHandle']?['products']?['nodes'] as List? ??
            [];
    return nodes
    .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e as Map)))
    .toList();
  }

  Future<List<CollectionModel>> fetchSelectedCollections() {
    return fetchCollectionsByHandles(HomeSectionHandles.selectedCollections);
  }

  Future<List<CollectionModel>> fetchSelectedCategories() {
    return fetchCollectionsByHandles(HomeSectionHandles.selectedCategories);
  }

  Future<HomeScreenData> fetchHomeScreenData() async {
    final results = await Future.wait([
      fetchBanners(),
      fetchSelectedCollections(),
      fetchSelectedCategories(),
      fetchLatestProducts(),
      fetchCollectionByHandle(HomeSectionHandles.promoBannerCollection),
      fetchCollectionByHandle(HomeSectionHandles.oversizedShirtCollection),
      fetchCollectionsByHandles(HomeSectionHandles.hotDealCollections),
    ]);

    final banners = results[0] as List<BannerModel>;
    final selectedCollections = results[1] as List<CollectionModel>;
    final selectedCategories = results[2] as List<CollectionModel>;
    final latestProducts = results[3] as List<ProductModel>;
    final promoBannerCollection = results[4] as CollectionModel?;
    final oversizedCollection = results[5] as CollectionModel?;
    final hotDealCollections = results[6] as List<CollectionModel>;

    final handles = <String>{
      ...selectedCollections.map((e) => e.handle),
      if (oversizedCollection != null) oversizedCollection.handle,
    }.toList();

    final productResults = await Future.wait(
      handles.map((handle) => fetchProductsByCollection(handle: handle)),
    );

    final Map<String, List<ProductModel>> collectionProducts = {};
    for (var i = 0; i < handles.length; i++) {
      collectionProducts[handles[i]] = productResults[i];
    }

    return HomeScreenData(
      banners: banners,
      selectedCollections: selectedCollections,
      selectedCategories: selectedCategories,
      latestProducts: latestProducts,
      collectionProducts: collectionProducts,
      promoBannerCollection: promoBannerCollection,
      oversizedCollection: oversizedCollection,
      hotDealCollections: hotDealCollections,
    );
  }
}