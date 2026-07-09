import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';

class CheckoutWebView extends StatefulWidget {
  const CheckoutWebView({super.key, required this.checkoutUrl});

  final String checkoutUrl;

  @override
  State<CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<CheckoutWebView> {
  static const Color primary = Color(ShopifyConstants.primaryColorHex);
  static const Color bgColor = Color(ShopifyConstants.bgColorHex);

  static const String _fBold = ShopifyConstants.fontBodyBold;
  static const String _fBody = ShopifyConstants.fontBody;

  // The WebView itself is inherently fluid (it fills whatever space it's
  // given), so responsiveness here is mostly about the chrome around it.
  // 400px logical width is the baseline (factor == 1.0).
  double get _sf =>
      (MediaQuery.of(context).size.width / 400).clamp(0.85, 1.3).toDouble();

  double _s(double base) => base * _sf;

  late final WebViewController _controller;
  bool _isLoading      = true;
  bool _orderCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _isLoading = false);
            _checkForOrderCompletion(url);
          },
          onNavigationRequest: (request) => _handleNavigationRequest(request),
          onWebResourceError: (error) {
            debugPrint('CheckoutWebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _checkForOrderCompletion(String url) {
    if (_orderCompleted) return;
    if (url.contains('thank_you') || url.contains('thank-you')) {
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

    if (isWebScheme) return NavigationDecision.navigate;

    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: primary,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Could not open payment app for this method.',
            style: TextStyle(
              fontFamily: _fBody,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    return NavigationDecision.prevent;
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: primary,
            onPressed: () async {
              if (await _controller.canGoBack()) {
                _controller.goBack();
              } else if (mounted) {
                Navigator.of(context).pop(false);
              }
            },
          ),
          title: Text(
            'CHECKOUT',
            style: TextStyle(
              fontFamily: _fBold,
              fontSize: _s(13),
              fontWeight: FontWeight.w800,
              color: primary,
              // letterSpacing: 1.8,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: primary),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.white,
                  child: Center(
                    child: CircularProgressIndicator(color: primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}