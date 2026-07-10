import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rookies_jeans/constant/shopify_constants.dart';

class ShopifyGraphQLResponse {
  final int statusCode;
  final Map<String, dynamic> body;

  const ShopifyGraphQLResponse(this.statusCode, this.body);

  bool get isOk => statusCode == 200;

  List<dynamic>? get errors => body['errors'] as List<dynamic>?;

  bool get hasErrors => errors != null;

  Map<String, dynamic>? get data => body['data'] as Map<String, dynamic>?;
}

class ShopifyGraphQL {
  ShopifyGraphQL._();

  static Future<ShopifyGraphQLResponse> post(
    String query, {
    Map<String, dynamic>? variables,
    String? tag,
  }) async {
    final response = await http.post(
      Uri.parse(ShopifyConstants.storefrontEndpoint),
      headers: ShopifyConstants.headers,
      body: jsonEncode({
        'query': query,
        if (variables != null) 'variables': variables,
      }),
    );

    if (tag != null) log(tag, '→ ${response.statusCode}');

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ShopifyGraphQLResponse(response.statusCode, decoded);
  }

  static void log(String scope, String message) {
    if (kDebugMode) debugPrint('[$scope] $message');
  }
}