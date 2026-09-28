import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rookies_jeans/constant/shopify_api.dart';
import 'package:rookies_jeans/models/cart_model.dart';

class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  static const String _cartIdPrefsKey = 'shopify_cart_id';

  String? _cartId;
  ShopifyCart _cart = ShopifyCart.empty;
  bool _isLoading = false;
  bool _initialized = false;

  ShopifyCart get cart => _cart;
  bool get isLoading => _isLoading;
  int get totalQuantity => _cart.totalQuantity;

  void _log(String msg) {
    if (kDebugMode) debugPrint('[CartService] $msg');
  }

  bool isInCart(String variantId) =>
      _cart.lines.any((l) => l.variantId == variantId && l.quantity > 0);

  int quantityForVariant(String variantId) {
    final matches = _cart.lines.where((l) => l.variantId == variantId);
    if (matches.isEmpty) return 0;
    return matches.first.quantity;
  }

  Future<void> initialize({bool forceRefresh = false}) async {
    if (_initialized && !forceRefresh) return;

    final prefs = await SharedPreferences.getInstance();
    _cartId = prefs.getString(_cartIdPrefsKey);

    if (_cartId != null) {
      await refresh();
    }

    _initialized = true;
  }

  Future<void> _persistCartId(String id) async {
    _cartId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartIdPrefsKey, id);
  }

  Future<void> _clearPersistedCartId() async {
    _cartId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartIdPrefsKey);
  }

  static const String _cartFragment = r'''
    fragment CartFields on Cart {
      id
      checkoutUrl
      totalQuantity
      cost {
        subtotalAmount { amount currencyCode }
      }
      lines(first: 100) {
        edges {
          node {
            id
            quantity
            merchandise {
              ... on ProductVariant {
                id
                title
                availableForSale
                priceV2: price { amount currencyCode }
                image { url }
                product {
                  handle
                  title
                  images(first: 1) { edges { node { url } } }
                }
              }
            }
          }
        }
      }
    }
  ''';

  Future<Map<String, dynamic>> _post(String query, Map<String, dynamic> variables) async {
    final res = await ShopifyGraphQL.post(query, variables: variables);
    return res.body;
  }

  Future<void> refresh() async {
    if (_cartId == null) {
      _cart = ShopifyCart.empty;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final query = '''
      query getCart(\$cartId: ID!) {
        cart(id: \$cartId) {
          ...CartFields
        }
      }
      $_cartFragment
    ''';

    try {
      final decoded = await _post(query, {'cartId': _cartId});
      _log('cart fetch → ${decoded['errors'] ?? 'ok'}');

      final cartNode = decoded['data']?['cart'];
      if (decoded['errors'] != null || cartNode == null) {
        await _clearPersistedCartId();
        _cart = ShopifyCart.empty;
      } else {
        _cart = ShopifyCart.fromJson(cartNode as Map<String, dynamic>);
      }
    } catch (e) {
      _log('refresh EXCEPTION: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> _createCart({required String variantId, required int quantity}) async {
    const mutation = r'''
      mutation cartCreate($input: CartInput) {
        cartCreate(input: $input) {
          cart { id }
          userErrors { field message }
        }
      }
    ''';

    try {
      final decoded = await _post(mutation, {
        'input': {
          'lines': [
            {'merchandiseId': variantId, 'quantity': quantity}
          ],
        },
      });

      _log('cartCreate → ${decoded['errors'] ?? 'ok'}');
      final data = decoded['data']?['cartCreate'];
      final userErrors = (data?['userErrors'] as List?) ?? [];
      if (decoded['errors'] != null || userErrors.isNotEmpty) {
        _log('cartCreate userErrors: $userErrors');
        return null;
      }
      return data?['cart']?['id'] as String?;
    } catch (e) {
      _log('_createCart EXCEPTION: $e');
      return null;
    }
  }

  Future<bool> addLine({required String variantId, int quantity = 1}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_cartId == null) {
        final newCartId = await _createCart(variantId: variantId, quantity: quantity);
        if (newCartId == null) return false;
        await _persistCartId(newCartId);
        await refresh();
        return true;
      }

      const mutation = r'''
        mutation cartLinesAdd($cartId: ID!, $lines: [CartLineInput!]!) {
          cartLinesAdd(cartId: $cartId, lines: $lines) {
            cart { id }
            userErrors { field message }
          }
        }
      ''';

      final decoded = await _post(mutation, {
        'cartId': _cartId,
        'lines': [
          {'merchandiseId': variantId, 'quantity': quantity}
        ],
      });

      _log('cartLinesAdd → ${decoded['errors'] ?? 'ok'}');
      final data = decoded['data']?['cartLinesAdd'];
      final userErrors = (data?['userErrors'] as List?) ?? [];

      if (decoded['errors'] != null || userErrors.isNotEmpty || data?['cart'] == null) {
        _log('cartLinesAdd userErrors: $userErrors');
        await _clearPersistedCartId();
        final newCartId = await _createCart(variantId: variantId, quantity: quantity);
        if (newCartId == null) return false;
        await _persistCartId(newCartId);
        await refresh();
        return true;
      }

      await refresh();
      return true;
    } catch (e) {
      _log('addLine EXCEPTION: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateLineQuantity({required String lineId, required int quantity}) async {
    if (_cartId == null) return false;

    if (quantity <= 0) {
      return removeLine(lineId: lineId);
    }

    _isLoading = true;
    notifyListeners();

    const mutation = r'''
      mutation cartLinesUpdate($cartId: ID!, $lines: [CartLineUpdateInput!]!) {
        cartLinesUpdate(cartId: $cartId, lines: $lines) {
          cart { id }
          userErrors { field message }
        }
      }
    ''';

    try {
      final decoded = await _post(mutation, {
        'cartId': _cartId,
        'lines': [
          {'id': lineId, 'quantity': quantity}
        ],
      });

      _log('cartLinesUpdate → ${decoded['errors'] ?? 'ok'}');
      final data = decoded['data']?['cartLinesUpdate'];
      final userErrors = (data?['userErrors'] as List?) ?? [];
      if (decoded['errors'] != null || userErrors.isNotEmpty) {
        _log('cartLinesUpdate userErrors: $userErrors');
        return false;
      }

      await refresh();
      return true;
    } catch (e) {
      _log('updateLineQuantity EXCEPTION: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeLine({required String lineId}) async {
    if (_cartId == null) return false;

    _isLoading = true;
    notifyListeners();

    const mutation = r'''
      mutation cartLinesRemove($cartId: ID!, $lineIds: [ID!]!) {
        cartLinesRemove(cartId: $cartId, lineIds: $lineIds) {
          cart { id }
          userErrors { field message }
        }
      }
    ''';

    try {
      final decoded = await _post(mutation, {
        'cartId': _cartId,
        'lineIds': [lineId],
      });

      _log('cartLinesRemove → ${decoded['errors'] ?? 'ok'}');
      final data = decoded['data']?['cartLinesRemove'];
      final userErrors = (data?['userErrors'] as List?) ?? [];
      if (decoded['errors'] != null || userErrors.isNotEmpty) {
        _log('cartLinesRemove userErrors: $userErrors');
        return false;
      }

      await refresh();
      return true;
    } catch (e) {
      _log('removeLine EXCEPTION: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

 Future<bool> linkCheckoutToCustomer({required String customerAccessToken}) async {
    if (_cartId == null) return false;

    const mutation = r'''
      mutation cartBuyerIdentityUpdate($cartId: ID!, $buyerIdentity: CartBuyerIdentityInput!) {
        cartBuyerIdentityUpdate(cartId: $cartId, buyerIdentity: $buyerIdentity) {
          cart { id }
          userErrors { field message }
        }
      }
    ''';

    try {
      final decoded = await _post(mutation, {
        'cartId': _cartId,
        'buyerIdentity': {
          'customerAccessToken': customerAccessToken,
        },
      });

      _log('cartBuyerIdentityUpdate → ${decoded['errors'] ?? 'ok'}');
      final data = decoded['data']?['cartBuyerIdentityUpdate'];
      final userErrors = (data?['userErrors'] as List?) ?? [];
      if (decoded['errors'] != null || userErrors.isNotEmpty) {
        _log('cartBuyerIdentityUpdate userErrors: $userErrors');
        return false;
      }

      await refresh();
      return true;
    } catch (e) {
      _log('linkCheckoutToCustomer EXCEPTION: $e');
      return false;
    }
  }
  
  Future<void> reset() async {
    await _clearPersistedCartId();
    _cart = ShopifyCart.empty;
    notifyListeners();
  }
}