import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/screens/products/products.dart' show ProductSortOption;
import 'package:rookies_jeans/services/shopify_storefront_service.dart' hide ProductSortOption;
import 'package:rookies_jeans/services/wishlist_service.dart';
import 'package:rookies_jeans/widget/price_text.dart';

class SearchResultsPage extends StatefulWidget {
  final String initialQuery;
  // Called when the user backs out of this page to the dashboard, so the
  // search tab it came from can clear its stale query/results — that tab's
  // state otherwise survives navigation (bottom-nav tabs stay alive).
  final VoidCallback? onBackToDashboard;
  const SearchResultsPage({super.key, required this.initialQuery, this.onBackToDashboard});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

// Mirrors the fixed price brackets ProductsPage offers under its "Price"
// filter section — Shopify's facets return real price *ranges* per query,
// not clean brackets, so both pages special-case this one category with a
// static list of brackets mapped onto the real filter id.
class _PriceOption {
  final String label;
  final double? min;
  final double? max;

  const _PriceOption({required this.label, this.min, this.max});

  String toShopifyInput() {
    final parts = <String>[];
    if (min != null) parts.add('"min":$min');
    if (max != null) parts.add('"max":$max');
    return '{"price":{${parts.join(',')}}}';
  }
}

const List<_PriceOption> _priceOptions = [
  _PriceOption(label: 'Under ₹999', max: 999.0),
  _PriceOption(label: '₹999 - ₹1,499', min: 999.0, max: 1499.0),
  _PriceOption(label: '₹1,499 - ₹1,999', min: 1499.0, max: 1999.0),
  _PriceOption(label: '₹1,999 - ₹2,499', min: 1999.0, max: 2499.0),
  _PriceOption(label: '₹2,499 - ₹2,999', min: 2499.0, max: 2999.0),
  _PriceOption(label: 'Above ₹2,999', min: 2999.0),
];

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

  // Same 6 sort labels the product page offers. Shopify's search API only
  // has server-side sort keys for RELEVANCE and PRICE though (no CREATED or
  // TITLE for `search`, confirmed against the Storefront API docs) — so
  // Newest/Title A-Z/Title Z-A are fetched at RELEVANCE and then re-sorted
  // client-side on whatever page of results is currently loaded. That's an
  // approximation, not a true full-catalog sort, but it keeps the option
  // available with a consistent label set instead of silently disappearing.
  ProductSortOption _sortOption = ProductSortOption.defaultSort;
  static const List<ProductSortOption> _availableSortOptions = ProductSortOption.values;

  String get _searchSortKey {
    switch (_sortOption) {
      case ProductSortOption.priceLowToHigh:
      case ProductSortOption.priceHighToLow:
        return 'PRICE';
      default:
        return 'RELEVANCE';
    }
  }

  bool get _searchReverse => _sortOption == ProductSortOption.priceHighToLow;

  // Real Shopify facets for this query, fetched alongside the products —
  // same source ProductsPage uses for collection browsing, so the filter
  // sheet here reflects whatever colors/sizes/etc. actually exist in the
  // current result set instead of a hand-picked list.
  List<ShopifyFilter> _availableFilters = [];
  final Map<String, Set<String>> _selectedFilterInputs = {};
  final Map<String, bool> _expandedFilters = {};
  int _activeFilterSectionIndex = 0;

  List<ShopifyFilter> get _visibleFilters => _availableFilters
      .where((filter) => filter.label.toLowerCase().trim() != 'availability')
      .toList();

  int get _activeFilterCount =>
      _selectedFilterInputs.values.fold(0, (sum, s) => sum + s.length);

  List<String> get _flatSelectedInputs =>
      _selectedFilterInputs.values.expand((s) => s).toList();

  void _applyClientSortIfNeeded() {
    switch (_sortOption) {
      case ProductSortOption.titleAZ:
        _products.sort((a, b) => a.title.compareTo(b.title));
        break;
      case ProductSortOption.titleZA:
        _products.sort((a, b) => b.title.compareTo(a.title));
        break;
      case ProductSortOption.newest:
        _products.sort((a, b) {
          final aDate = a.createdAt;
          final bDate = b.createdAt;
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        });
        break;
      default:
        break;
    }
  }

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
        sortKey: _searchSortKey,
        reverse: _searchReverse,
        filters: _flatSelectedInputs,
      );
      if (!mounted) return;
      setState(() {
        _products = response.products;
        _applyClientSortIfNeeded();
        _hasNextPage = response.hasNextPage;
        _endCursor = response.endCursor;
        if (response.filters.isNotEmpty) {
          _availableFilters = response.filters;
        }
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
        sortKey: _searchSortKey,
        reverse: _searchReverse,
        filters: _flatSelectedInputs,
      );
      if (!mounted) return;
      setState(() {
        _products.addAll(response.products);
        _applyClientSortIfNeeded();
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

  void _applySort(ProductSortOption sort) {
    if (sort == _sortOption) return;
    setState(() => _sortOption = sort);
    _fetchInitial();
  }

  void _applyFilters(Map<String, Set<String>> newSelection) {
    setState(() {
      _selectedFilterInputs
        ..clear()
        ..addAll(newSelection);
    });
    _fetchInitial();
  }

  void _goToDashboard() {
    widget.onBackToDashboard?.call();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    context.go('/home');
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
                onPressed: _goToDashboard,
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
                _sortOption.label.toUpperCase(),
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
    final active = _activeFilterCount > 0;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _openFilterSheet(context),
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
                active ? 'FILTERS ($_activeFilterCount)' : 'FILTERS',
                style: TextStyle(fontFamily: _fBold, fontSize: 12, fontWeight: FontWeight.w800, color: primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // isScrollControlled + an explicit max height keep this scrollable instead
  // of overflowing — 6 sort options no longer fit the sheet's default,
  // unscrolled intrinsic-height sizing on shorter screens.
  void _openSortSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
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
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: _availableSortOptions.map((option) {
                    final isSelected = option == _sortOption;
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
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openFilterSheet(BuildContext context) {
    final draft = Map<String, Set<String>>.from(
      _selectedFilterInputs.map((k, v) => MapEntry(k, {...v})),
    );

    int localActiveIndex = _activeFilterSectionIndex;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final screenSize = MediaQuery.of(sheetContext).size;
        final railWidth = (screenSize.width * 0.32).clamp(96.0, 200.0);
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final draftActiveCount =
                draft.values.fold<int>(0, (sum, s) => sum + s.length);

            if (_visibleFilters.isEmpty) {
              return SafeArea(
                child: SizedBox(
                  height: 320,
                  child: Center(
                    child: Text(
                      'No filters available for this search.',
                      style: TextStyle(fontSize: 12, color: secondaryTxt),
                    ),
                  ),
                ),
              );
            }

            if (localActiveIndex >= _visibleFilters.length) {
              localActiveIndex = 0;
            }

            final activeFilter = _visibleFilters[localActiveIndex];
            final selected = draft[activeFilter.id] ?? <String>{};

            final isPriceFilter = activeFilter.label.toLowerCase().contains('price');
            final isColorFilter = activeFilter.label.toLowerCase().contains('color');
            final isExpanded = _expandedFilters[activeFilter.id] ?? false;
            final canShowMore = isColorFilter && activeFilter.values.length > 15;

            final visibleValues = canShowMore && !isExpanded
                ? activeFilter.values.take(15).toList()
                : activeFilter.values;

            return SafeArea(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SizedBox(
                  height: screenSize.height * (screenSize.height < 600 ? 0.92 : 0.82),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Row(
                          children: [
                            Text(
                              'Filters',
                              style: TextStyle(fontFamily: _fBody, fontSize: 16, color: primary),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: draftActiveCount == 0
                                  ? null
                                  : () => setSheetState(() => draft.clear()),
                              child: Text(
                                'Clear All',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: borderColor),
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: railWidth,
                              decoration: BoxDecoration(
                                color: bgColor,
                                border: Border(
                                  right: BorderSide(color: borderColor.withOpacity(0.8)),
                                ),
                              ),
                              child: ListView.builder(
                                itemCount: _visibleFilters.length,
                                itemBuilder: (context, index) {
                                  final filter = _visibleFilters[index];
                                  final isActive = index == localActiveIndex;
                                  final count = draft[filter.id]?.length ?? 0;

                                  return InkWell(
                                    onTap: () => setSheetState(() => localActiveIndex = index),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: isActive ? cardColor : Colors.transparent,
                                        border: Border(
                                          left: BorderSide(
                                            color: isActive ? primary : Colors.transparent,
                                            width: 3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              filter.label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                                color: primary,
                                              ),
                                            ),
                                          ),
                                          if (count > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: primary,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '$count',
                                                style: TextStyle(
                                                  color: onPrimary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeFilter.label,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: isPriceFilter
                                          ? _priceOptionsSection(
                                              activeFilter: activeFilter,
                                              draft: draft,
                                              setSheetState: setSheetState,
                                            )
                                          : ListView.separated(
                                              itemCount: visibleValues.length + (canShowMore ? 1 : 0),
                                              separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                                              itemBuilder: (context, index) {
                                                if (canShowMore && index == visibleValues.length) {
                                                  return InkWell(
                                                    onTap: () => setSheetState(() {
                                                      _expandedFilters[activeFilter.id] = !isExpanded;
                                                    }),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                                      child: Text(
                                                        isExpanded ? 'Show less' : 'Show more',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                          color: primary,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }

                                                final value = visibleValues[index];
                                                final isSelected = selected.contains(value.input);

                                                return InkWell(
                                                  onTap: () => setSheetState(() {
                                                    final set = draft.putIfAbsent(activeFilter.id, () => <String>{});
                                                    if (isSelected) {
                                                      set.remove(value.input);
                                                      if (set.isEmpty) draft.remove(activeFilter.id);
                                                    } else {
                                                      set.add(value.input);
                                                    }
                                                  }),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          width: 18,
                                                          height: 18,
                                                          decoration: BoxDecoration(
                                                            border: Border.all(
                                                              color: isSelected ? primary : borderColor,
                                                            ),
                                                            borderRadius: BorderRadius.circular(4),
                                                            color: isSelected ? primary : Colors.transparent,
                                                          ),
                                                          child: isSelected
                                                              ? Icon(Icons.check, size: 13, color: onPrimary)
                                                              : null,
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            value.label,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: primary,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ),
                                                        if (value.count > 0)
                                                          Text(
                                                            '${value.count}',
                                                            style: TextStyle(fontSize: 11, color: secondaryTxt),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          border: Border(top: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setSheetState(() => draft.clear()),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(color: primary, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _activeFilterSectionIndex = localActiveIndex;
                                  Navigator.pop(sheetContext);
                                  _applyFilters(draft);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: onPrimary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                child: Text(
                                  draftActiveCount > 0 ? 'Apply ($draftActiveCount)' : 'Apply',
                                  style: TextStyle(color: onPrimary, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _priceOptionsSection({
    required ShopifyFilter activeFilter,
    required Map<String, Set<String>> draft,
    required void Function(void Function()) setSheetState,
  }) {
    final selected = draft[activeFilter.id] ?? <String>{};

    return ListView.separated(
      itemCount: _priceOptions.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
      itemBuilder: (context, index) {
        final option = _priceOptions[index];
        final input = option.toShopifyInput();
        final isSelected = selected.contains(input);

        return InkWell(
          onTap: () => setSheetState(() {
            if (isSelected) {
              draft.remove(activeFilter.id);
            } else {
              draft[activeFilter.id] = {input};
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    border: Border.all(color: isSelected ? primary : borderColor),
                    borderRadius: BorderRadius.circular(4),
                    color: isSelected ? primary : cardColor,
                  ),
                  child: isSelected ? Icon(Icons.check, size: 13, color: onPrimary) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: primary),
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
      return PriceText(
        product.formattedPrice,
        currencyCode: product.currencyCode,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: primary,
        amountFontFamily: _fBold,
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        PriceText(
          product.formattedPrice,
          currencyCode: product.currencyCode,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: primary,
          amountFontFamily: _fBold,
        ),
        PriceText(
          product.formattedCompareAtPrice,
          currencyCode: product.currencyCode,
          fontSize: 11,
          color: secondaryTxt,
          amountFontFamily: _fBody,
          decoration: TextDecoration.lineThrough,
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
