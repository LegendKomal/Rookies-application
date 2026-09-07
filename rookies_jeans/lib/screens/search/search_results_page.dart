import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';
import 'package:rookies_jeans/services/wishlist_service.dart';
import 'package:rookies_jeans/widget/price_text.dart';

enum _SearchSort {
  relevance('Relevance', 'RELEVANCE', false),
  newest('Newest', 'CREATED', true),
  priceLowToHigh('Price: Low to High', 'PRICE', false),
  priceHighToLow('Price: High to Low', 'PRICE', true),
  titleAZ('Alphabetically: A-Z', 'TITLE', false),
  titleZA('Alphabetically: Z-A', 'TITLE', true);

  const _SearchSort(this.label, this.shopifyKey, this.reverse);
  final String label;
  final String shopifyKey;
  final bool reverse;
}

class _PriceBracket {
  final String label;
  final double? min;
  final double? max;
  const _PriceBracket(this.label, this.min, this.max);
}

const List<_PriceBracket> _priceBrackets = [
  _PriceBracket('Under ₹999', null, 999),
  _PriceBracket('₹999 - ₹1,499', 999, 1499),
  _PriceBracket('₹1,499 - ₹1,999', 1499, 1999),
  _PriceBracket('₹1,999 - ₹2,499', 1999, 2499),
  _PriceBracket('Above ₹2,499', 2499, null),
];

class SearchResultsPage extends StatefulWidget {
  final String initialQuery;
  const SearchResultsPage({super.key, required this.initialQuery});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  static Color get primary => AppColors.primary;
  static Color get onPrimary => AppColors.onPrimary;
  static Color get bgColor => AppColors.bg;
  static Color get cardColor => AppColors.card;
  static Color get secondaryTxt => AppColors.secondaryText;
  static Color get borderColor => AppColors.border;

  static const String _fHead = AppFonts.heading;
  static const String _fBody = AppFonts.body;
  static const String _fBold = AppFonts.bold;

  static const double _kGridPadding = 12.0;
  static const double _kCrossSpacing = 12.0;
  static const double _kMainSpacing = 14.0;
  static const double _kAspect = 0.6;

  late final TextEditingController _searchCtrl =
      TextEditingController(text: widget.initialQuery);
  final ScrollController _scrollController = ScrollController();

  String _query = '';
  List<ShopifyProduct> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = false;
  String? _endCursor;
  String? _error;

  _SearchSort _sort = _SearchSort.relevance;
  _PriceBracket? _priceFilter;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _fetchInitial();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_isLoading &&
          !_isLoadingMore &&
          _hasNextPage) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _runNewSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    setState(() => _query = trimmed);
    _fetchInitial();
  }

  Future<void> _fetchInitial() async {
    if (_query.isEmpty) {
      setState(() {
        _products = [];
        _isLoading = false;
        _hasNextPage = false;
        _endCursor = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _products = [];
      _endCursor = null;
      _hasNextPage = false;
    });

    try {
      final response = await ShopifyStorefrontService.instance.searchProductsPaginated(
        _query,
        first: 24,
        sortKey: _sort.shopifyKey,
        reverse: _sort.reverse,
        minPrice: _priceFilter?.min,
        maxPrice: _priceFilter?.max,
      );
      if (!mounted) return;
      setState(() {
        _products = response.products;
        _hasNextPage = response.hasNextPage;
        _endCursor = response.endCursor;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load results. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasNextPage) return;
    setState(() => _isLoadingMore = true);

    try {
      final response = await ShopifyStorefrontService.instance.searchProductsPaginated(
        _query,
        first: 24,
        after: _endCursor,
        sortKey: _sort.shopifyKey,
        reverse: _sort.reverse,
        minPrice: _priceFilter?.min,
        maxPrice: _priceFilter?.max,
      );
      if (!mounted) return;
      setState(() {
        _products.addAll(response.products);
        _hasNextPage = response.hasNextPage;
        _endCursor = response.endCursor;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _refresh() async {
    ShopifyStorefrontService.instance.clearCache();
    await _fetchInitial();
  }

  void _applySort(_SearchSort sort) {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    _fetchInitial();
  }

  void _applyPriceFilter(_PriceBracket? bracket) {
    setState(() => _priceFilter = bracket);
    _fetchInitial();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: _isLoading
                    ? _shimmerGrid()
                    : RefreshIndicator(
                        color: primary,
                        onRefresh: _refresh,
                        child: _error != null
                            ? _errorState()
                            : _products.isEmpty
                                ? _emptyState()
                                : _resultsBody(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: cardColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: primary, size: 18),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 14),
            child: Text(
              'SEARCH RESULT',
              style: TextStyle(
                fontFamily: _fHead,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _runNewSearch,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                fontFamily: _fBody,
                fontSize: 15,
                color: primary,
              ),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(color: secondaryTxt),
                prefixIcon: Icon(Icons.search_rounded, color: secondaryTxt),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: secondaryTxt),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 14),
          if (!_isLoading && _error == null)
            Text(
              '${_products.length}${_hasNextPage ? '+' : ''} result${_products.length == 1 ? '' : 's'} found for "$_query"',
              style: TextStyle(
                fontFamily: _fBody,
                fontSize: 13,
                color: secondaryTxt,
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultsBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: borderColor),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _sortButton(),
              const SizedBox(width: 10),
              _filterButton(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _productGrid()),
      ],
    );
  }

  Widget _sortButton() {
    return Expanded(
      child: OutlinedButton(
        onPressed: _openSortSheet,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor),
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SORT BY: ',
                style: TextStyle(fontFamily: _fBody, fontSize: 12, color: primary),
              ),
              Text(
                _sort.label.toUpperCase(),
                style: TextStyle(fontFamily: _fBold, fontSize: 12, fontWeight: FontWeight.w800, color: primary),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterButton() {
    final active = _priceFilter != null;
    return Expanded(
      child: OutlinedButton(
        onPressed: _openFilterSheet,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor),
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 16, color: primary),
              const SizedBox(width: 6),
              Text(
                active ? 'FILTERS (1)' : 'FILTERS',
                style: TextStyle(fontFamily: _fBold, fontSize: 12, fontWeight: FontWeight.w800, color: primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SORT BY',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primary),
                ),
              ),
            ),
            Divider(height: 1, color: borderColor),
            ..._SearchSort.values.map((option) {
              final isSelected = option == _sort;
              return ListTile(
                title: Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: primary,
                  ),
                ),
                trailing: isSelected ? Icon(Icons.check_rounded, color: primary) : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _applySort(option);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openFilterSheet() {
    _PriceBracket? draft = _priceFilter;
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'PRICE',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: primary),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: draft == null
                            ? null
                            : () => setSheetState(() => draft = null),
                        child: Text('Clear', style: TextStyle(color: primary)),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: borderColor),
                ..._priceBrackets.map((bracket) {
                  final isSelected = draft?.label == bracket.label;
                  return ListTile(
                    title: Text(
                      bracket.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: primary,
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check_rounded, color: primary) : null,
                    onTap: () => setSheetState(() => draft = bracket),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _applyPriceFilter(draft);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: onPrimary,
                        shape: const RoundedRectangleBorder(),
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _productGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(_kGridPadding, 0, _kGridPadding, 24),
      itemCount: _products.length + (_isLoadingMore ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: _kMainSpacing,
        crossAxisSpacing: _kCrossSpacing,
        childAspectRatio: _kAspect,
      ),
      itemBuilder: (_, i) {
        if (i >= _products.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return _productCard(_products[i]);
      },
    );
  }

  Widget _productCard(ShopifyProduct product) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(
            handle: product.handle,
            title: product.title,
            heroImageUrl: product.primaryImageUrl,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: primary.withOpacity(0.15), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: AppColors.fieldFill,
                  child: product.primaryImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: product.primaryImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.fieldFill),
                          errorWidget: (_, __, ___) => Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.hint,
                          ),
                        )
                      : Icon(Icons.image_not_supported_outlined, color: AppColors.hint),
                ),
                if (product.isOnSale)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: const BoxDecoration(color: AppColors.danger),
                      child: Text(
                        '${_discountPercent(product)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: AnimatedBuilder(
                    animation: WishlistService.instance,
                    builder: (context, _) {
                      final wishlisted = WishlistService.instance.isWishlisted(product.id);
                      return GestureDetector(
                        onTap: () => WishlistService.instance.toggleProduct(product),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(0.85),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 16,
                            color: wishlisted ? AppColors.danger : primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: primary.withOpacity(0.1))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _fBody,
                    fontSize: 12,
                    color: primary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                _priceRow(product),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(ShopifyProduct product) {
    if (!product.isOnSale) {
      return Text(
        product.formattedPrice,
        style: TextStyle(
          fontFamily: _fBold,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          product.formattedPrice,
          style: TextStyle(fontFamily: _fBold, fontSize: 13, fontWeight: FontWeight.w700, color: primary),
        ),
        Text(
          product.formattedCompareAtPrice,
          style: TextStyle(
            fontFamily: _fBody,
            fontSize: 11,
            color: secondaryTxt,
            decoration: TextDecoration.lineThrough,
            decorationColor: secondaryTxt,
          ),
        ),
      ],
    );
  }

  String _discountPercent(ShopifyProduct product) {
    if (product.compareAtPrice == null || product.compareAtPrice == 0) return '0';
    final pct = ((1 - product.price / product.compareAtPrice!) * 100).round();
    return '$pct';
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: AppColors.hint),
              const SizedBox(height: 16),
              Text(
                'No results for "$_query"',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: _fBold, fontSize: 14, fontWeight: FontWeight.w700, color: primary),
              ),
              const SizedBox(height: 6),
              Text(
                'Try a different search term or clear your filters.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: _fBody, fontSize: 12, color: secondaryTxt),
              ),
            ],
          ),
        ),
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.hint),
              const SizedBox(height: 14),
              Text(
                _error ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: secondaryTxt),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _fetchInitial,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('RETRY'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _shimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(_kGridPadding),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: _kMainSpacing,
        crossAxisSpacing: _kCrossSpacing,
        childAspectRatio: _kAspect,
      ),
      itemBuilder: (_, __) => Container(color: AppColors.fieldFill),
    );
  }
}
