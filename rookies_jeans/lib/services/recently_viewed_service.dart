import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Products the customer has opened, newest first. Saved on the device so
/// the list survives app restarts; every product detail page records itself
/// here and lists the rest in its "Recently Viewed" row.
class RecentlyViewedService extends ChangeNotifier {
  RecentlyViewedService._();
  static final RecentlyViewedService instance = RecentlyViewedService._();

  static const int _maxItems = 30;
  static const String _prefsKey = 'recently_viewed_products';

  final List<ShopifyProduct> _items = [];
  bool _initialized = false;

  List<ShopifyProduct> get items => List.unmodifiable(_items);

  /// Loads the saved list. Products recorded before this finishes stay in
  /// front of the saved ones.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final saved = (jsonDecode(raw) as List)
          .map((e) => _fromJson(e as Map<String, dynamic>))
          .where((p) => !_items.any((item) => item.id == p.id));
      _items.addAll(saved);
      if (_items.length > _maxItems) {
        _items.removeRange(_maxItems, _items.length);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('RecentlyViewedService load error: $e');
    }
  }

  /// Moves [product] to the front (adding it if new).
  void record(ShopifyProduct product) {
    _items.removeWhere((p) => p.id == product.id);
    _items.insert(0, product);
    if (_items.length > _maxItems) _items.removeRange(_maxItems, _items.length);
    notifyListeners();
    _save();
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode(_items.map(_toJson).toList()));
    } catch (e) {
      debugPrint('RecentlyViewedService save error: $e');
    }
  }

  // Only what a product card needs; price is as seen when last opened.
  static Map<String, dynamic> _toJson(ShopifyProduct p) => {
        'id': p.id,
        'title': p.title,
        'handle': p.handle,
        'price': p.price,
        'compareAtPrice': p.compareAtPrice,
        'currencyCode': p.currencyCode,
        'imageUrls': p.imageUrls,
      };

  static ShopifyProduct _fromJson(Map<String, dynamic> json) => ShopifyProduct(
        id: json['id'] as String,
        title: json['title'] as String,
        handle: json['handle'] as String,
        price: (json['price'] as num).toDouble(),
        compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
        currencyCode: json['currencyCode'] as String,
        imageUrls: List<String>.from(json['imageUrls'] as List),
        variants: const [],
        options: const [],
      );
}
