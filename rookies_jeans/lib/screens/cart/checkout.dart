import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/cart_model.dart';

/// GoKwik checkout screen.
///
/// Checkout runs through GoKwik (the "Gokwik X Rookies" Shopify app), which
/// is launched by a script in the storefront theme rather than from
/// Shopify's native `checkoutUrl`. So we load the storefront, copy the app's
/// cart into the web cart and launch GoKwik the same way the website's
/// Checkout button does. There is deliberately no fallback to Shopify's
/// native checkout: if GoKwik can't be started, we show an error with Retry.
class CheckoutWebView extends StatefulWidget {
  const CheckoutWebView({super.key, required this.lines});

  /// Cart lines to check out.
  final List<ShopifyCartLine> lines;

  @override
  State<CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<CheckoutWebView> {
  static Color get primary => AppColors.primary;
  static Color get onPrimary => AppColors.onPrimary;
  static Color get bgColor => AppColors.bg;
  static Color get cardColor => AppColors.card;
  static Color get secondaryText => AppColors.secondaryText;
  static Color get hint => AppColors.hint;

  static const String _fBold = AppFonts.bold;
  static const String _fBody = AppFonts.body;

  static const String _bridgeName = 'RookiesCheckout';
  /// The storefront is heavy and can take a while on slower phones, so each
  /// launch step gets its own time budget instead of one overall deadline.
  static const Duration _pageLoadTimeout = Duration(seconds: 45);
  static const Duration _stepTimeout     = Duration(seconds: 30);

  double _s(double base) =>
      Responsive.of(context, baseW: 400, maxScale: 1.3).s(base);

  late final WebViewController _controller;
  bool _isLoading      = true;
  bool _orderCompleted = false;

  /// True while the storefront is loading and GoKwik is being launched.
  bool _launchingGokwik = false;
  bool _gokwikInjected  = false;
  Timer? _gokwikTimer;

  /// Shown instead of the web view when GoKwik could not be started.
  String? _error;

  /// Bumped on every navigation, so a GoKwik "modal closed" event that is
  /// followed by a redirect (e.g. to the thank-you page) doesn't close us.
  int _navigationCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(_bridgeName, onMessageReceived: _onBridgeMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _navigationCount++;
            if (mounted) setState(() => _isLoading = true);
            _checkForOrderCompletion(url);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _checkForOrderCompletion(url);
            _maybeLaunchGokwik(url);
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _checkForOrderCompletion(url);
          },
          onNavigationRequest: (request) => _handleNavigationRequest(request),
          onWebResourceError: (error) {
            debugPrint('CheckoutWebView error: ${error.description}');
            if (error.isForMainFrame == true && _launchingGokwik) {
              _fail('page load error: ${error.description}');
            }
          },
        ),
      );
    _startGokwik();
  }

  @override
  void dispose() {
    _gokwikTimer?.cancel();
    super.dispose();
  }

  /// Converts app cart lines to the storefront's `/cart/add.js` format.
  /// Storefront API variant IDs are GIDs; the web cart needs the numeric ID.
  List<Map<String, int>> _gokwikItems() {
    final items = <Map<String, int>>[];
    for (final line in widget.lines) {
      final id = int.tryParse(line.variantId.split('/').last.split('?').first);
      if (id == null || line.quantity <= 0) continue;
      items.add({'id': id, 'quantity': line.quantity});
    }
    return items;
  }

  void _startGokwik() {
    if (_gokwikItems().isEmpty) {
      _fail('no valid cart lines');
      return;
    }
    setState(() {
      _error           = null;
      _launchingGokwik = true;
      _gokwikInjected  = false;
    });
    _armTimer(_pageLoadTimeout, 'page load timeout');
    _controller.loadRequest(Uri.parse('${ShopifyConstants.storeUrl}/cart'));
  }

  void _armTimer(Duration timeout, String reason) {
    _gokwikTimer?.cancel();
    _gokwikTimer = Timer(timeout, () {
      if (_launchingGokwik) _fail(reason);
    });
  }

  void _maybeLaunchGokwik(String url) {
    if (!_launchingGokwik || _gokwikInjected) return;
    final host = Uri.tryParse(url)?.host;
    if (host != Uri.parse(ShopifyConstants.storeUrl).host) return;

    _gokwikInjected = true;
    _armTimer(_stepTimeout, 'GoKwik script timeout');
    final items = jsonEncode(_gokwikItems());
    _controller.runJavaScript('''
(function () {
  function post(m) { try { $_bridgeName.postMessage(m); } catch (e) {} }
  var items = $items;
  var tries = 0;
  function waitForGokwik() {
    if (typeof window.triggerGokwikCustomCheckout === 'function' && window.gokwikSdk) {
      start();
      return;
    }
    if (++tries > 100) { post('failed:gokwik-not-loaded'); return; }
    setTimeout(waitForGokwik, 250);
  }
  function start() {
    post('step:gokwik-ready');
    fetch('/cart/clear.js', { method: 'POST', credentials: 'same-origin' })
      .then(function () {
        return fetch('/cart/add.js', {
          method: 'POST',
          credentials: 'same-origin',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ items: items })
        });
      })
      .then(function (r) { if (!r.ok) throw new Error('cart add ' + r.status); })
      .then(function () {
        post('step:cart-ready');
        window.gokwikSdk.on('modal_closed', function () { post('closed'); });
        window.triggerGokwikCustomCheckout();
        post('opened');
      })
      .catch(function (e) { post('failed:' + e); });
  }
  waitForGokwik();
})();
''');
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    final msg = message.message;
    if (!mounted) return;

    if (msg == 'opened') {
      // Also clears an earlier timeout error if GoKwik opened late.
      _gokwikTimer?.cancel();
      setState(() {
        _launchingGokwik = false;
        _error = null;
      });
    } else if (msg.startsWith('step:')) {
      debugPrint('CheckoutWebView: $msg');
      if (_launchingGokwik) _armTimer(_stepTimeout, 'timeout after $msg');
    } else if (msg == 'closed') {
      // Closing the GoKwik sheet without paying returns to the cart. Wait a
      // moment first: after a successful order GoKwik closes the sheet and
      // then redirects, which we must not interrupt.
      final navBefore = _navigationCount;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || _orderCompleted) return;
        if (_navigationCount != navBefore) return;
        Navigator.of(context).pop(false);
      });
    } else if (msg.startsWith('failed')) {
      _fail(msg);
    }
  }

  void _fail(String reason) {
    debugPrint('CheckoutWebView: GoKwik could not start ($reason)');
    _gokwikTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _launchingGokwik = false;
      _error = 'Checkout is unavailable right now.\nPlease try again in a moment.';
    });
  }

  void _checkForOrderCompletion(String url) {
    if (_orderCompleted) return;
    final lower = url.toLowerCase();
    final isThankYou = lower.contains('thank_you') ||
        lower.contains('thank-you') ||
        lower.contains('thankyou') ||
        // Shopify order status page, where GoKwik lands after payment.
        lower.contains('/orders/');
    if (isThankYou) {
      _orderCompleted = true;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    }
  }

  Future<NavigationDecision> _handleNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    final scheme      = uri.scheme.toLowerCase();
    final isWebScheme = scheme == 'http' || scheme == 'https';
    // iOS (WKWebView) also reports iframe loads here, and GoKwik's payment
    // sheet creates about:blank / about:srcdoc / blob: frames. These must
    // load in the web view, not be handed to launchUrl as a "payment app".
    final isInternalScheme = scheme == 'about' ||
        scheme == 'data' ||
        scheme == 'blob' ||
        scheme == 'javascript';

    if (isWebScheme || isInternalScheme) return NavigationDecision.navigate;

    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: primary,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Could not open payment app for this method.',
            style: TextStyle(
              fontFamily: _fBody,
              color: onPrimary,
            ),
          ),
        ),
      );
    }
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: primary,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        leadingWidth: 44,
        titleSpacing: 0,
        title: Text(
          'CHECKOUT',
          maxLines: 1,
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: (MediaQuery.of(context).size.width * 0.09)
                .clamp(20.0, 40.0),
            fontStyle: FontStyle.italic,
            height: 1,
            color: primary,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: primary),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_error != null)
            Positioned.fill(child: _errorView(_error!))
          else if (_isLoading || _launchingGokwik)
            Positioned.fill(
              child: ColoredBox(
                color: bgColor,
                child: Center(
                  child: CircularProgressIndicator(color: primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _errorView(String message) => ColoredBox(
        color: bgColor,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(_s(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: _s(48), color: hint),
                SizedBox(height: _s(12)),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _fBody,
                    fontSize: _s(13),
                    color: secondaryText,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: _s(20)),
                ElevatedButton(
                  onPressed: _startGokwik,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: onPrimary,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(),
                    padding: EdgeInsets.symmetric(
                        horizontal: _s(28), vertical: _s(12)),
                  ),
                  child: Text(
                    'RETRY',
                    style: TextStyle(
                      fontFamily: _fBold,
                      fontSize: _s(13),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
