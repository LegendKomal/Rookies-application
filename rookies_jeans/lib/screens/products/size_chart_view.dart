import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Displays a Kiwi size chart in a WebView.
///
/// The [controller] is created and navigated by the caller (see
/// `_prewarmSizeChart` in ProductDetailPage) as soon as the product loads,
/// so that by the time this sheet opens the page has often already finished
/// loading in the background — avoiding a cold WebView + network round trip
/// in the tap-to-open critical path.
class SizeChartView extends StatelessWidget {
  final WebViewController controller;
  final ValueListenable<bool> loading;

  const SizeChartView({
    super.key,
    required this.controller,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Stack(
        children: [
          WebViewWidget(controller: controller),
          ValueListenableBuilder<bool>(
            valueListenable: loading,
            builder: (context, isLoading, _) => isLoading
                ? const Center(child: CircularProgressIndicator())
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
