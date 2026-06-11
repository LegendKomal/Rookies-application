import 'package:rookies_jeans/models/banner_model.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/product_model.dart';

class HomeScreenData {
  final List<BannerModel> banners;
  final List<CollectionModel> selectedCollections;
  final List<CollectionModel> selectedCategories;
  final List<ProductModel> latestProducts;
  final Map<String, List<ProductModel>> collectionProducts;
  final CollectionModel? promoBannerCollection;
  final CollectionModel? oversizedCollection;
  final List<CollectionModel> hotDealCollections;

  const HomeScreenData({
    required this.banners,
    required this.selectedCollections,
    required this.selectedCategories,
    required this.latestProducts,
    required this.collectionProducts,
    required this.promoBannerCollection,
    required this.oversizedCollection,
    required this.hotDealCollections,
  });
}