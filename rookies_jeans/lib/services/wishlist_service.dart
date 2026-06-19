import 'package:flutter/foundation.dart';
import 'package:rookies_jeans/models/product_model.dart';

class WishlistService extends ChangeNotifier {
  WishlistService._();
  static final WishlistService instance = WishlistService._();

  final Map<String, ShopifyProduct> _wishlistProducts = {};

  bool isWishlisted(String productId) {
    return _wishlistProducts.containsKey(productId);
  }

  List<ShopifyProduct> get items {
    return _wishlistProducts.values.toList();
  }

  int get count => _wishlistProducts.length;

  void toggleProduct(ShopifyProduct product) {
    if (_wishlistProducts.containsKey(product.id)) {
      _wishlistProducts.remove(product.id);
    } else {
      _wishlistProducts[product.id] = product;
    }
    notifyListeners();
  }

  void removeById(String productId) {
    _wishlistProducts.remove(productId);
    notifyListeners();
  }

  void clear() {
    _wishlistProducts.clear();
    notifyListeners();
  }
}