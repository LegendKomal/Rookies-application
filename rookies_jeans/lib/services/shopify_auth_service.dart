import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rookies_jeans/models/auth_model.dart';
import 'package:rookies_jeans/models/shopify_customer_model.dart';

class ShopifyAuthService {
  ShopifyAuthService._();
  static final ShopifyAuthService instance = ShopifyAuthService._();

  static const String _shopDomain = 'rookies-jeans.myshopify.com';
  static const String _storefrontToken = '8127f95aa12da6ed0234550d19abd043';
  static const String _apiVersion = '2026-04';

  static const String _customerTokenKey = 'shopify_customer_access_token';
  static const String _customerTokenExpiryKey = 'shopify_customer_access_token_expiry';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String get _endpoint => 'https://$_shopDomain/api/$_apiVersion/graphql.json';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': _storefrontToken,
      };

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return 'null';
    if (token.length <= 8) return '********';
    return '${token.substring(0, 4)}****${token.substring(token.length - 4)}';
  }

  Future<ShopifyAuthResult> login({
    required String email,
    required String password,
  }) async {
    _log('AUTH LOGIN START -> email: $email');
    _log('AUTH ENDPOINT -> $_endpoint');

    const String mutation = r'''
      mutation customerAccessTokenCreate($input: CustomerAccessTokenCreateInput!) {
        customerAccessTokenCreate(input: $input) {
          customerAccessToken {
            accessToken
            expiresAt
          }
          customerUserErrors {
            field
            message
            code
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'query': mutation,
          'variables': {
            'input': {
              'email': email.trim(),
              'password': password,
            }
          }
        }),
      );

      _log('AUTH LOGIN STATUS -> ${response.statusCode}');

      final Map<String, dynamic> decoded = jsonDecode(response.body);

      if (kDebugMode) {
        _log('AUTH LOGIN JSON -> ${jsonEncode(decoded)}');
      }

      if (response.statusCode != 200) {
        _log('AUTH LOGIN FAILED -> HTTP ${response.statusCode}');
        return ShopifyAuthResult(
          success: false,
          message: 'Login failed. HTTP ${response.statusCode}',
        );
      }

      if (decoded['errors'] != null) {
        _log('AUTH GRAPHQL ERROR -> ${decoded['errors']}');
        return ShopifyAuthResult(
          success: false,
          message: decoded['errors'][0]['message'] ?? 'Something went wrong.',
        );
      }

      final data = decoded['data']?['customerAccessTokenCreate'];
      if (data == null) {
        _log('AUTH LOGIN FAILED -> data.customerAccessTokenCreate is null');
        return ShopifyAuthResult(
          success: false,
          message: 'Invalid server response.',
        );
      }

      final List errors = data['customerUserErrors'] ?? [];
      if (errors.isNotEmpty) {
        _log('AUTH CUSTOMER USER ERRORS -> $errors');
        return ShopifyAuthResult(
          success: false,
          message: errors.first['message'] ?? 'Invalid email or password.',
        );
      }

      final tokenData = data['customerAccessToken'];
      final String? accessToken = tokenData?['accessToken'];
      final String? expiresAt = tokenData?['expiresAt'];

      _log('AUTH TOKEN RECEIVED -> ${_maskToken(accessToken)}');
      _log('AUTH TOKEN EXPIRES -> $expiresAt');

      if (accessToken == null || accessToken.isEmpty) {
        _log('AUTH LOGIN FAILED -> accessToken missing');
        return ShopifyAuthResult(
          success: false,
          message: 'Customer token not found.',
        );
      }

      await _storage.write(key: _customerTokenKey, value: accessToken);
      await _storage.write(key: _customerTokenExpiryKey, value: expiresAt ?? '');

      _log('AUTH TOKEN SAVED -> secure storage');

      final customer = await getCurrentCustomer();

      _log('AUTH LOGIN SUCCESS -> customer: ${customer?.toJson()}');

      return ShopifyAuthResult(
        success: true,
        message: 'Login successful',
        accessToken: accessToken,
        expiresAt: expiresAt,
        customer: customer,
      );
    } catch (e, stack) {
      _log('AUTH LOGIN EXCEPTION -> $e');
      _log('AUTH LOGIN STACK -> $stack');
      return ShopifyAuthResult(
        success: false,
        message: 'Something went wrong: $e',
      );
    }
  }

  Future<ShopifyAuthResult> recoverPassword({
    required String email,
  }) async {
    _log('AUTH RECOVER START -> email: $email');
    _log('AUTH ENDPOINT -> $_endpoint');

    const String mutation = r'''
      mutation customerRecover($email: String!) {
        customerRecover(email: $email) {
          customerUserErrors {
            field
            message
            code
          }
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'query': mutation,
          'variables': {
            'email': email.trim(),
          }
        }),
      );

      _log('AUTH RECOVER STATUS -> ${response.statusCode}');

      final Map<String, dynamic> decoded = jsonDecode(response.body);

      if (kDebugMode) {
        _log('AUTH RECOVER JSON -> ${jsonEncode(decoded)}');
      }

      if (response.statusCode != 200) {
        _log('AUTH RECOVER FAILED -> HTTP ${response.statusCode}');
        return ShopifyAuthResult(
          success: false,
          message: 'Request failed. HTTP ${response.statusCode}',
        );
      }

      if (decoded['errors'] != null) {
        _log('AUTH RECOVER GRAPHQL ERROR -> ${decoded['errors']}');
        return ShopifyAuthResult(
          success: false,
          message: decoded['errors'][0]['message'] ?? 'Something went wrong.',
        );
      }

      final data = decoded['data']?['customerRecover'];
      if (data == null) {
        _log('AUTH RECOVER FAILED -> data.customerRecover is null');
        return ShopifyAuthResult(
          success: false,
          message: 'Invalid server response.',
        );
      }

      final List errors = data['customerUserErrors'] ?? [];
      if (errors.isNotEmpty) {
        _log('AUTH RECOVER CUSTOMER USER ERRORS -> $errors');
        return ShopifyAuthResult(
          success: false,
          message: errors.first['message'] ?? 'Could not process that request.',
        );
      }

      _log('AUTH RECOVER SUCCESS -> recovery email dispatched (if account exists)');

      return ShopifyAuthResult(
        success: true,
        message:
            'If an account exists for that email, a password reset link has been sent.',
      );
    } catch (e, stack) {
      _log('AUTH RECOVER EXCEPTION -> $e');
      _log('AUTH RECOVER STACK -> $stack');
      return ShopifyAuthResult(
        success: false,
        message: 'Something went wrong: $e',
      );
    }
  }

  Future<ShopifyCustomer?> getCurrentCustomer() async {
    final token = await _storage.read(key: _customerTokenKey);

    _log('CUSTOMER FETCH START -> token: ${_maskToken(token)}');

    if (token == null || token.isEmpty) {
      _log('CUSTOMER FETCH STOP -> token not found');
      return null;
    }

    const String query = r'''
      query getCustomer($customerAccessToken: String!) {
        customer(customerAccessToken: $customerAccessToken) {
          id
          firstName
          lastName
          email
          phone
          acceptsMarketing
        }
      }
    ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'query': query,
          'variables': {
            'customerAccessToken': token,
          }
        }),
      );

      _log('CUSTOMER FETCH STATUS -> ${response.statusCode}');

      final Map<String, dynamic> decoded = jsonDecode(response.body);

      if (kDebugMode) {
        _log('CUSTOMER FETCH JSON -> ${jsonEncode(decoded)}');
      }

      if (response.statusCode != 200) {
        _log('CUSTOMER FETCH FAILED -> HTTP ${response.statusCode}');
        return null;
      }

      if (decoded['errors'] != null) {
        _log('CUSTOMER FETCH GRAPHQL ERROR -> ${decoded['errors']}');
        return null;
      }

      final customerJson = decoded['data']?['customer'];
      if (customerJson == null) {
        _log('CUSTOMER FETCH FAILED -> customer is null');
        return null;
      }

      final customer = ShopifyCustomer.fromJson(customerJson);
      _log('CUSTOMER FETCH SUCCESS -> ${customer.toJson()}');
      return customer;
    } catch (e, stack) {
      _log('CUSTOMER FETCH EXCEPTION -> $e');
      _log('CUSTOMER FETCH STACK -> $stack');
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
  final token = await _storage.read(key: _customerTokenKey);
  final expiry = await _storage.read(key: _customerTokenExpiryKey);

  if (token == null || token.isEmpty) {
    _log('AUTH IS LOGGED IN -> false (no token)');
    return false;
  }

  if (expiry != null && expiry.isNotEmpty) {
    final expiryDate = DateTime.tryParse(expiry);
    if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
      _log('AUTH IS LOGGED IN -> false (token expired)');
      await logout();
      return false;
    }
  }

  _log('AUTH IS LOGGED IN -> true');
  return true;
}

  Future<void> logout() async {
    _log('AUTH LOGOUT START');
    await _storage.delete(key: _customerTokenKey);
    await _storage.delete(key: _customerTokenExpiryKey);
    _log('AUTH LOGOUT DONE');
  }

  Future<String?> getSavedCustomerToken() async {
    final token = await _storage.read(key: _customerTokenKey);
    _log('AUTH SAVED TOKEN -> ${_maskToken(token)}');
    return token;
  }
}