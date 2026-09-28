import 'package:flutter/material.dart';
import 'package:rookies_jeans/screens/products/products.dart';

/// Full search results for a query. Rendered by ProductsPage in search mode
/// so results share the exact collection-browsing UI: collapsing banner,
/// grid-mode / filter / sort toolbar, product cards, quick add-to-cart and
/// long-press peek.
class SearchResultsPage extends StatelessWidget {
  final String initialQuery;
  // Called when the user jumps from this page back to the dashboard, so the
  // search tab it came from can clear its stale query/results — that tab's
  // state otherwise survives navigation (bottom-nav tabs stay alive).
  final VoidCallback? onBackToDashboard;
  const SearchResultsPage({super.key, required this.initialQuery, this.onBackToDashboard});

  @override
  Widget build(BuildContext context) => ProductsPage.search(
        searchQuery: initialQuery,
        onBackToDashboard: onBackToDashboard,
      );
}
