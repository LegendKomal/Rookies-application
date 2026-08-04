import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SizeChartView extends StatefulWidget {
  final String shop;         // e.g. 'rookiesjeans.myshopify.com'
  final String productId;    // numeric id, no gid:// prefix
  final String vendor;
  final String type;
  final String tags;         // comma-delimited
  final String collections;  // comma-delimited ids
  final String source;       // Kiwi-issued partner id

  const SizeChartView({
    super.key,
    required this.shop,
    required this.productId,
    this.vendor = '',
    this.type = '',
    this.tags = '',
    this.collections = '',
    required this.source,
  });

  @override
  State<SizeChartView> createState() => _SizeChartViewState();
}

class _SizeChartViewState extends State<SizeChartView> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final uri = Uri.https('app.kiwisizing.com', '/size', {
      'shop': widget.shop,
      'product': widget.productId,
      'vendor': widget.vendor,
      'type': widget.type,
      'tags': widget.tags,
      'collections': widget.collections,
      'source': widget.source,
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}