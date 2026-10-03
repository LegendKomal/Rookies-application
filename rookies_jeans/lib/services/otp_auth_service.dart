import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/auth_model.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';

/// Result of verifying an OTP. Either the customer is signed in ([auth] set),
/// or the phone is verified but name + email are needed to finish creating
/// the account ([needsProfile], use [verificationToken]).
class OtpVerifyResult {
  final ShopifyAuthResult? auth;
  final bool needsProfile;
  final String? verificationToken;
  final String firstName;
  final String lastName;
  final String? error;

  const OtpVerifyResult({
    this.auth,
    this.needsProfile = false,
    this.verificationToken,
    this.firstName = '',
    this.lastName = '',
    this.error,
  });

  bool get success => auth?.success == true;
}

/// Phone OTP login.
///
/// 1. Send / resend / verify the OTP with MSG91's Flutter SDK, using the app's
///    own mobile-only OTP widget (the website keeps its separate OTPLOGIN one)
///    — widget ID + token are safe to ship in the app.
/// 2. Hand MSG91's access token to the otp_login_worker, which checks it with
///    MSG91 and returns a Shopify customer access token — stored exactly like
///    an email/password login.
class OtpAuthService {
  OtpAuthService._();
  static final OtpAuthService instance = OtpAuthService._();

  static const Duration _timeout = Duration(seconds: 20);

  // MSG91 retry channel codes.
  static const int _channelSms   = 11;
  static const int _channelWhatsApp = 12;

  bool _widgetReady = false;

  /// MSG91 request id for the OTP currently in flight.
  String? _reqId;

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  /// "+919876543210" -> "919876543210" (MSG91 wants no "+").
  String _msg91Identifier(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  /// Returns null on success, otherwise a user-facing error message.
  Future<String?> sendOtp(String phone) async {
    _reqId = null;
    final res = await _msg91(OTPWidget.sendOTP, {
      'identifier': _msg91Identifier(phone),
    });
    if (res.error != null) return res.error;

    _reqId = res.body['message']?.toString();
    if (_reqId == null || _reqId!.isEmpty) return 'Could not send OTP. Please try again.';
    return null;
  }

  /// [channel] is 'text' (SMS) or 'whatsapp'.
  Future<String?> resendOtp(String phone, {String channel = 'text'}) async {
    if (_reqId == null) return sendOtp(phone);
    final res = await _msg91(OTPWidget.retryOTP, {
      'reqId': _reqId,
      'retryChannel': channel == 'whatsapp' ? _channelWhatsApp : _channelSms,
    });
    return res.error;
  }

  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    if (_reqId == null) {
      return const OtpVerifyResult(error: 'Please request an OTP first.');
    }

    final verified = await _msg91(OTPWidget.verifyOTP, {'reqId': _reqId, 'otp': otp});
    if (verified.error != null) return OtpVerifyResult(error: verified.error);

    final msg91Token = verified.body['message']?.toString() ??
        verified.body['access-token']?.toString();
    if (msg91Token == null || msg91Token.isEmpty) {
      return const OtpVerifyResult(error: 'Invalid response from OTP service.');
    }

    final res = await _worker('/login', {'phone': phone, 'accessToken': msg91Token});
    if (res.error != null) return OtpVerifyResult(error: res.error);

    _reqId = null;
    if (res.body['status'] == 'profile_required') {
      return OtpVerifyResult(
        needsProfile: true,
        verificationToken: res.body['verificationToken'] as String?,
        firstName: res.body['firstName'] as String? ?? '',
        lastName: res.body['lastName'] as String? ?? '',
      );
    }
    return _signIn(res.body);
  }

  Future<OtpVerifyResult> completeProfile({
    required String verificationToken,
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final res = await _worker('/complete', {
      'verificationToken': verificationToken,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
    });
    if (res.error != null) return OtpVerifyResult(error: res.error);
    return _signIn(res.body);
  }

  Future<OtpVerifyResult> _signIn(Map<String, dynamic> body) async {
    final token = body['accessToken'] as String?;
    if (body['status'] != 'signed_in' || token == null || token.isEmpty) {
      return const OtpVerifyResult(error: 'Invalid server response.');
    }
    final auth = await ShopifyAuthService.instance.signInWithToken(
      accessToken: token,
      expiresAt: body['expiresAt'] as String?,
    );
    return OtpVerifyResult(auth: auth);
  }

  // ---------------------------------------------------------------------------
  // HTTP

  /// MSG91 OTP widget, through MSG91's Flutter SDK. Success is
  /// `{"type": "success", "message": ...}`; failures come back as
  /// `{"type": "error", "message": "..."}` (the SDK throws on non-2xx).
  Future<({Map<String, dynamic> body, String? error})> _msg91(
    Future<Map<String, dynamic>?> Function(Map<String, dynamic>) call,
    Map<String, dynamic> payload,
  ) async {
    if (ShopifyConstants.msg91WidgetId.startsWith('YOUR_') ||
        ShopifyConstants.msg91TokenAuth.startsWith('YOUR_') ||
        ShopifyConstants.otpLoginUrl.contains('YOUR-SUBDOMAIN')) {
      return (
        body: const <String, dynamic>{},
        error: 'Phone login is not set up yet. Please use email & password.',
      );
    }

    if (!_widgetReady) {
      OTPWidget.initializeWidget(
        ShopifyConstants.msg91WidgetId,
        ShopifyConstants.msg91TokenAuth,
      );
      _widgetReady = true;
    }

    Map<String, dynamic> body;
    try {
      body = await call(payload).timeout(_timeout) ?? const {};
    } on TimeoutException {
      return (
        body: const <String, dynamic>{},
        error: 'The request timed out. Please try again.',
      );
    } catch (e) {
      _log('MSG91 EXCEPTION -> $e');
      body = _jsonIn(e.toString());
      if (body.isEmpty) {
        return (
          body: body,
          error: 'Could not reach the server. Check your connection.',
        );
      }
    }

    if (body['type'] != 'success') {
      return (
        body: body,
        error: body['message']?.toString() ?? 'OTP request failed.',
      );
    }
    return (body: body, error: null);
  }

  /// The SDK reports HTTP errors as "Failed to post data: 400, {...}";
  /// pull MSG91's JSON back out so its message reaches the user.
  Map<String, dynamic> _jsonIn(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return const {};
    try {
      return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  Future<({Map<String, dynamic> body, String? error})> _worker(
    String path,
    Map<String, dynamic> payload,
  ) =>
      _post('${ShopifyConstants.otpLoginUrl}$path', payload);

  Future<({Map<String, dynamic> body, String? error})> _post(
    String url,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse(url);
    _log('OTP ${uri.path} START');

    try {
      final response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      _log('OTP ${uri.path} STATUS -> ${response.statusCode}');

      Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        body = const {};
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (
          body: body,
          error: (body['error'] ?? body['message'])?.toString() ??
              'Request failed (${response.statusCode}).',
        );
      }
      return (body: body, error: null);
    } on TimeoutException {
      return (
        body: const <String, dynamic>{},
        error: 'The request timed out. Please try again.${_debugUrl(uri)}',
      );
    } catch (e) {
      _log('OTP ${uri.path} EXCEPTION -> $e');
      return (
        body: const <String, dynamic>{},
        error: 'Could not reach the server. Check your connection.${_debugUrl(uri)}',
      );
    }
  }

  // Debug builds name the host they tried, so a wrong URL is obvious.
  String _debugUrl(Uri uri) => kDebugMode ? '\n(${uri.origin})' : '';
}
