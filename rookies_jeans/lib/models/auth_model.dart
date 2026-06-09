import 'shopify_customer_model.dart';

class ShopifyAuthResult {
  final bool success;
  final String? message;
  final String? accessToken;
  final String? expiresAt;
  final ShopifyCustomer? customer;

  ShopifyAuthResult({
    required this.success,
    this.message,
    this.accessToken,
    this.expiresAt,
    this.customer,
  });
}