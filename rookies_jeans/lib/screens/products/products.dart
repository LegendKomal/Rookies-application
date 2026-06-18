import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';

class ProductsPage extends StatefulWidget {
  final ShopifyCollection collection;

  const ProductsPage({super.key, required this.collection});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  static const Color primary = Color(ShopifyConstants.primaryColorHex);
  static const Color bgColor = Color(ShopifyConstants.bgColorHex);
  static const Color cardColor = Color(ShopifyConstants.cardColorHex);
  static const Color secondaryTxt = Color(ShopifyConstants.secondaryTextHex);
  static const Color borderColor = Color(ShopifyConstants.borderColorHex);

  final ScrollController _scrollController = ScrollController();

  List<ShopifyProduct> _products = [];
  List<ShopifyFilter> _availableFilters = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  bool _isAddingToCart = false;
  String? _endCursor;
  String? _error;

  ProductSortOption _sortOption = ProductSortOption.defaultSort;

  final Map<String, Set<String>> _selectedFilterInputs = {};
  final Map<String, bool> _expandedFilters = {};
  int _activeFilterSectionIndex = 0;

  List<ShopifyFilter> get _visibleFilters {
    return _availableFilters
        .where((filter) => filter.label.toLowerCase().trim() != 'availability')
        .toList();
  }

  final List<_PriceOption> _priceOptions = const [
    _PriceOption(label: 'Under ₹999', min: null, max: 999),
    _PriceOption(label: '₹999 - ₹1,499', min: 999, max: 1499),
    _PriceOption(label: '₹1,499 - ₹1,999', min: 1499, max: 1999),
    _PriceOption(label: '₹1,999 - ₹2,499', min: 1999, max: 2499),
    _PriceOption(label: '₹2,499 - ₹2,999', min: 2499, max: 2999),
    _PriceOption(label: 'Above ₹2,999', min: 2999, max: null),
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialProducts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_isLoading &&
          !_isLoadingMore &&
          _hasNextPage) {
        _loadMoreProducts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int get _activeFilterCount =>
      _selectedFilterInputs.values.fold(0, (sum, s) => sum + s.length);

  List<String> get _flatSelectedInputs =>
      _selectedFilterInputs.values.expand((s) => s).toList();

  Future<void> _fetchInitialProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _products = [];
        _endCursor = null;
        _hasNextPage = true;
      });
    }

    try {
      final response = await ShopifyStorefrontService.instance
          .getProductsByCollectionPaginated(
        widget.collection.handle,
        first: 24,
        sortKey: _sortOption.shopifyKey,
        reverse: _sortOption.reverse,
        filters: _flatSelectedInputs,
      );

      if (!mounted) return;

      setState(() {
        _products = response.products;
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
        _error = 'Failed to load products. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasNextPage) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await ShopifyStorefrontService.instance
          .getProductsByCollectionPaginated(
        widget.collection.handle,
        first: 24,
        after: _endCursor,
        sortKey: _sortOption.shopifyKey,
        reverse: _sortOption.reverse,
        filters: _flatSelectedInputs,
      );

      if (!mounted) return;

      setState(() {
        _products.addAll(response.products);
        _hasNextPage = response.hasNextPage;
        _endCursor = response.endCursor;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshProducts() async {
    ShopifyStorefrontService.instance.clearCache();
    await _fetchInitialProducts();
  }

  void _applySort(ProductSortOption option) {
    if (option == _sortOption) return;
    setState(() => _sortOption = option);
    _fetchInitialProducts();
  }

  void _applyFilters(Map<String, Set<String>> newSelection) {
    setState(() {
      _selectedFilterInputs
        ..clear()
        ..addAll(newSelection);
    });
    _fetchInitialProducts();
  }

  void _clearAllFilters() {
    if (_selectedFilterInputs.isEmpty) return;
    setState(() => _selectedFilterInputs.clear());
    _fetchInitialProducts();
  }

  Future<void> _handleAddToCart(ShopifyProduct product) async {
    if (_isAddingToCart) return;

    setState(() {
      _isAddingToCart = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    bool success = false;
    try {
      success =
          await ShopifyStorefrontService.instance.addProductToCart(product);
    } catch (_) {
      success = false;
    }

    if (!mounted) return;

    setState(() {
      _isAddingToCart = false;
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${product.title} added to cart'
              : 'Failed to add item to cart',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _floatingFilterButton(context),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: _isLoading
                  ? _shimmerGrid()
                  : RefreshIndicator(
                      color: primary,
                      onRefresh: _refreshProducts,
                      child: _error != null
                          ? _errorState()
                          : _products.isEmpty
                              ? _emptyState()
                              : _productGrid(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _floatingFilterButton(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => _openFilterSheet(context),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  _activeFilterCount > 0
                      ? 'FILTERS ($_activeFilterCount)'
                      : 'FILTERS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Container(
        color: cardColor,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: primary,
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.collection.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primary,
                  letterSpacing: 1.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _sortButton(context),
            ),
          ],
        ),
      );

  Widget _sortButton(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _openSortSheet(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swap_vert_rounded, size: 17, color: primary),
                SizedBox(width: 4),
                Text(
                  'SORT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _productGrid() => GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: _products.length + (_isLoadingMore ? 1 : 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.52,
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

  void _openSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SORT BY',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: primary,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, color: borderColor),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: ProductSortOption.values.map((option) {
                      final isSelected = option == _sortOption;
                      return ListTile(
                        title: Text(
                          option.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: primary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded, color: primary)
                            : null,
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
        );
      },
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
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final draftActiveCount =
                draft.values.fold<int>(0, (sum, s) => sum + s.length);

            if (_visibleFilters.isEmpty) {
              return const SafeArea(
                child: SizedBox(
                  height: 320,
                  child: Center(
                    child: Text(
                      'No filters available for this collection.',
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

            final isPriceFilter =
                activeFilter.label.toLowerCase().contains('price');
            final isColorFilter =
                activeFilter.label.toLowerCase().contains('color');
            final isExpanded = _expandedFilters[activeFilter.id] ?? false;
            final canShowMore =
                isColorFilter && activeFilter.values.length > 15;

            final visibleValues = canShowMore && !isExpanded
                ? activeFilter.values.take(15).toList()
                : activeFilter.values;

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.82,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        children: [
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: draftActiveCount == 0
                                ? null
                                : () {
                                    setSheetState(() {
                                      draft.clear();
                                    });
                                  },
                            child: const Text(
                              'Clear All',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: borderColor),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 120,
                            decoration: BoxDecoration(
                              color: bgColor,
                              border: Border(
                                right: BorderSide(
                                  color: borderColor.withOpacity(0.8),
                                ),
                              ),
                            ),
                            child: ListView.builder(
                              itemCount: _visibleFilters.length,
                              itemBuilder: (context, index) {
                                final filter = _visibleFilters[index];
                                final isActive = index == localActiveIndex;
                                final count = draft[filter.id]?.length ?? 0;

                                return InkWell(
                                  onTap: () {
                                    setSheetState(() {
                                      localActiveIndex = index;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? cardColor
                                          : Colors.transparent,
                                      border: Border(
                                        left: BorderSide(
                                          color: isActive
                                              ? primary
                                              : Colors.transparent,
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
                                              fontWeight: isActive
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: primary,
                                            ),
                                          ),
                                        ),
                                        if (count > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primary,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$count',
                                              style: const TextStyle(
                                                color: Colors.white,
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
                              padding:
                                  const EdgeInsets.fromLTRB(12, 12, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeFilter.label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primary,
                                    ),
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
                                            itemCount: visibleValues.length +
                                                (canShowMore ? 1 : 0),
                                            separatorBuilder: (_, __) =>
                                                const Divider(
                                              height: 1,
                                              color: Color(0xFFF1F1F1),
                                            ),
                                            itemBuilder: (context, index) {
                                              if (canShowMore &&
                                                  index ==
                                                      visibleValues.length) {
                                                return InkWell(
                                                  onTap: () {
                                                    setSheetState(() {
                                                      _expandedFilters[
                                                              activeFilter.id] =
                                                          !isExpanded;
                                                    });
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      vertical: 14,
                                                    ),
                                                    child: Text(
                                                      isExpanded
                                                          ? 'Show less'
                                                          : 'Show more',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: primary,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }

                                              final value =
                                                  visibleValues[index];
                                              final isSelected = selected
                                                  .contains(value.input);

                                              return InkWell(
                                                onTap: () {
                                                  setSheetState(() {
                                                    final set = draft
                                                        .putIfAbsent(
                                                      activeFilter.id,
                                                      () => <String>{},
                                                    );
                                                    if (isSelected) {
                                                      set.remove(value.input);
                                                      if (set.isEmpty) {
                                                        draft.remove(
                                                            activeFilter.id);
                                                      }
                                                    } else {
                                                      set.add(value.input);
                                                    }
                                                  });
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    vertical: 12,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 18,
                                                        height: 18,
                                                        decoration:
                                                            BoxDecoration(
                                                          border: Border.all(
                                                            color: isSelected
                                                                ? primary
                                                                : borderColor,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                          color: isSelected
                                                              ? primary
                                                              : Colors.white,
                                                        ),
                                                        child: isSelected
                                                            ? const Icon(
                                                                Icons.check,
                                                                size: 13,
                                                                color: Colors
                                                                    .white,
                                                              )
                                                            : null,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Text(
                                                          value.label,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 12,
                                                            color: primary,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      if (value.count > 0)
                                                        Text(
                                                          '${value.count}',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                secondaryTxt,
                                                          ),
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
                      decoration: const BoxDecoration(
                        color: cardColor,
                        border: Border(
                          top: BorderSide(color: borderColor),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  draft.clear();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              child: const Text(
                                'Clear',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w700,
                                ),
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              child: Text(
                                draftActiveCount > 0
                                    ? 'Apply ($draftActiveCount)'
                                    : 'Apply',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        color: Color(0xFFF1F1F1),
      ),
      itemBuilder: (context, index) {
        final option = _priceOptions[index];
        final input = option.toShopifyInput();
        final isSelected = selected.contains(input);

        return InkWell(
          onTap: () {
            setSheetState(() {
              if (isSelected) {
                draft.remove(activeFilter.id);
              } else {
                draft[activeFilter.id] = {input};
              }
            });
          },
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
                    color: isSelected ? primary : Colors.white,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    option.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: primary,
                      fontWeight: FontWeight.w500,
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

  Widget _productCard(ShopifyProduct product) {
    final colorHexes = product.colorHexCodes;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(
              handle: product.handle,
              title: product.title,
              heroImageUrl: product.primaryImageUrl,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(10)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product.primaryImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: product.primaryImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: const Color(0xFFEEEEEE)),
                            errorWidget: (_, __, ___) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                    if (product.isOnSale)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _discountPercent(product),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _priceBlock(product),
                  if (colorHexes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _colorSwatches(colorHexes),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: OutlinedButton(
                      onPressed: _isAddingToCart
                          ? null
                          : () => _handleAddToCart(product),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primary, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: EdgeInsets.zero,
                        foregroundColor: primary,
                      ),
                      child: _isAddingToCart
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'SHOP NOW',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: primary,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        color: const Color(0xFFEEEEEE),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFFBBBBBB),
          size: 32,
        ),
      );

  Widget _priceBlock(ShopifyProduct product) {
    if (!product.isOnSale) {
      return Text(
        product.formattedPrice,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      );
    }

    final saved = (product.compareAtPrice! - product.price).round();
    final savedStr = product.currencyCode == 'INR'
        ? '₹$saved'
        : '${product.currencyCode} $saved';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              product.formattedCompareAtPrice,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF9A9A9A),
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xFF9A9A9A),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              product.formattedPrice,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Save $savedStr',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _colorSwatches(List<String> hexCodes) {
    final visible = hexCodes.take(5).toList();
    return Row(
      children: visible.map((hex) {
        Color color;
        try {
          final cleaned = hex.replaceAll('#', '');
          color = Color(int.parse('FF$cleaned', radix: 16));
        } catch (_) {
          color = const Color(0xFFCCCCCC);
        }
        return Container(
          margin: const EdgeInsets.only(right: 4),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
          ),
        );
      }).toList(),
    );
  }

  String _discountPercent(ShopifyProduct product) {
    if (product.compareAtPrice == null || product.compareAtPrice == 0) {
      return 'SALE';
    }
    final pct =
        ((1 - product.price / product.compareAtPrice!) * 100).round();
    return '$pct% OFF';
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 14),
            const Text(
              'No products found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _activeFilterCount > 0
                  ? 'Try removing some filters.'
                  : 'Check back soon for new arrivals.',
              style: const TextStyle(fontSize: 12, color: secondaryTxt),
            ),
          ],
        ),
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 52,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 14),
              Text(
                _error ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: secondaryTxt),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _fetchInitialProducts,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('RETRY'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: const BorderSide(color: primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _shimmerGrid() => GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.52,
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
}

class _PriceOption {
  final String label;
  final double? min;
  final double? max;

  const _PriceOption({
    required this.label,
    this.min,
    this.max,
  });

  String toShopifyInput() {
    final parts = <String>[];
    if (min != null) parts.add('"min":$min');
    if (max != null) parts.add('"max":$max');
    return '{"price":{${parts.join(',')}}}';
  }
}

enum ProductSortOption {
  defaultSort('Default', 'COLLECTION_DEFAULT', false),
  newest('Newest', 'CREATED', true),
  priceLowToHigh('Price: Low to High', 'PRICE', false),
  priceHighToLow('Price: High to Low', 'PRICE', true),
  titleAZ('Alphabetically: A-Z', 'TITLE', false),
  titleZA('Alphabetically: Z-A', 'TITLE', true);

  const ProductSortOption(this.label, this.shopifyKey, this.reverse);

  final String label;
  final String shopifyKey;
  final bool reverse;
} 