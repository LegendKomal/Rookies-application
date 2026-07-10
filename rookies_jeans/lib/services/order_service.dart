import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/constant/shopify_api.dart';

class ShopifyOrderException implements Exception {
  final String code;
  const ShopifyOrderException(this.code);

  String get userMessage {
    switch (code) {
      case 'not_logged_in':
        return 'Please sign in to view your orders.';
      case 'fetch_failed':
        return 'Failed to load orders. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

enum OrderState { active, delivered, cancelled }

class ShopifyOrderService {
  ShopifyOrderService._();
  static final ShopifyOrderService instance = ShopifyOrderService._();

  static const _storage = FlutterSecureStorage();

  Future<String?> _getToken() async {
    final token = await _storage.read(key: 'shopify_customer_access_token');
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final token = await _getToken();
    if (token == null) throw const ShopifyOrderException('not_logged_in');

    const String query = r'''
      query getOrders($customerAccessToken: String!) {
        customer(customerAccessToken: $customerAccessToken) {
          orders(first: 20, sortKey: PROCESSED_AT, reverse: true) {
            edges {
              node {
                id
                orderNumber
                processedAt
                financialStatus
                fulfillmentStatus
                canceledAt
                currentTotalPrice {
                  amount
                  currencyCode
                }
                lineItems(first: 5) {
                  edges {
                    node {
                      title
                      quantity
                      variant {
                        image { url }
                        price { amount currencyCode }
                        selectedOptions { name value }
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
      final res = await ShopifyGraphQL.post(
        query,
        variables: {'customerAccessToken': token},
      );

      if (res.statusCode != 200) {
        throw const ShopifyOrderException('fetch_failed');
      }

      final decoded = res.body;
      if (decoded['errors'] != null) throw const ShopifyOrderException('fetch_failed');

      final edges =
          (decoded['data']?['customer']?['orders']?['edges'] as List?) ?? [];
      return edges.map((e) => e['node'] as Map<String, dynamic>).toList();
    } on ShopifyOrderException {
      rethrow;
    } catch (_) {
      throw const ShopifyOrderException('fetch_failed');
    }
  }

  OrderState resolveOrderState(Map<String, dynamic> order) {
    final canceledAt      = order['canceledAt'];
    final financialStatus = (order['financialStatus'] ?? '').toString().toUpperCase();
    final fulfillStatus   = (order['fulfillmentStatus'] ?? '').toString().toUpperCase();

    if (canceledAt != null && canceledAt.toString().isNotEmpty) return OrderState.cancelled;
    if (financialStatus == 'REFUNDED') return OrderState.cancelled;
    if (fulfillStatus == 'FULFILLED') return OrderState.delivered;
    return OrderState.active;
  }

  bool isCod(Map<String, dynamic> order) {
    final financialStatus = (order['financialStatus'] ?? '').toString().toUpperCase();
    return financialStatus == 'PENDING';
  }

  bool canCancelOrder(Map<String, dynamic> order) {
    if (resolveOrderState(order) != OrderState.active) return false;
    final fulfillStatus = (order['fulfillmentStatus'] ?? '').toString().toUpperCase();
    return fulfillStatus == 'UNFULFILLED';
  }

  String orderCancelUrl(String rawGraphqlId) {
    final numericId = rawGraphqlId.split('/').last;
    return '${ShopifyConstants.storeUrl}/account/orders/$numericId';
  }

  String orderTrackUrl() => ShopifyConstants.shiprocketUrl;

  String formatPrice(Map<String, dynamic> price) {
    final amount   = double.tryParse(price['amount']?.toString() ?? '0') ?? 0;
    final currency = price['currencyCode'] ?? 'INR';
    if (currency == 'INR') return '₹${amount.toStringAsFixed(2)}';
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  String formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  String formatStatus(String status) {
    return status
        .toLowerCase()
        .split('_')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}