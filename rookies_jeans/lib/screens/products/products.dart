import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';
import 'package:rookies_jeans/services/cart_service.dart';
import 'package:rookies_jeans/screens/cart/cart.dart';

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
  final Set<String> _addingToCartProductIds = {};
  final Map<String, bool> _fillAnimatingIds = {};
  String? _endCursor;
  String? _error;

  static const String _fHead = ShopifyConstants.fontHeading;
  static const String _fBody = ShopifyConstants.fontBody;
  static const String _fBold = ShopifyConstants.fontBodyBold;
  static const String _fBodyBold = ShopifyConstants.fontAlteBold;
  static const String _fNumber = ShopifyConstants.fontNumber;
  static const String _fRupee = ShopifyConstants.fontRupee;

  ProductSortOption _sortOption = ProductSortOption.defaultSort;

  final Map<String, Set<String>> _selectedFilterInputs = {};
  final Map<String, bool> _expandedFilters = {};
  int _activeFilterSectionIndex = 0;

  final Map<String, PageController> _imagePageControllers = {};

  final Map<String, ValueNotifier<int>> _currentImageIndex = {};

  Timer? _autoScrollTimer;
  final Random _random = Random();

  List<ShopifyFilter> get _visibleFilters {
    return _availableFilters
        .where((filter) => filter.label.toLowerCase().trim() != 'availability')
        .toList();
  }

  final List<_PriceOption> _priceOptions = const [
    _PriceOption(label: 'Under ₹999', min: null, max: 999.0),
    _PriceOption(label: '₹999 - ₹1,499', min: 999.0, max: 1499.0),
    _PriceOption(label: '₹1,499 - ₹1,999', min: 1499.0, max: 1999.0),
    _PriceOption(label: '₹1,999 - ₹2,499', min: 1999.0, max: 2499.0),
    _PriceOption(label: '₹2,499 - ₹2,999', min: 2499.0, max: 2999.0),
    _PriceOption(label: 'Above ₹2,999', min: 2999.0, max: null),
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
    _autoScrollTimer?.cancel();
    for (final c in _imagePageControllers.values) {
      c.dispose();
    }
    for (final n in _currentImageIndex.values) {
      n.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _syncPageControllers() {
    final currentIds = _products.map((p) => p.id).toSet();

    final removed = _imagePageControllers.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in removed) {
      _imagePageControllers.remove(id)?.dispose();
      _currentImageIndex.remove(id)?.dispose();
    }

    for (final product in _products) {
      if (!_imagePageControllers.containsKey(product.id)) {
        _imagePageControllers[product.id] = PageController();
        _currentImageIndex[product.id] = ValueNotifier<int>(0);
      }
    }
  }

  void _startAutoScrollTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _autoScrollRandomCard();
    });
  }

  List<int> _visibleProductIndices() {
    if (!_scrollController.hasClients || !mounted) return [];

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    const crossAxisCount = 2;
    const mainAxisSpacing = 14.0;
    const horizontalPadding = 12.0;
    const crossAxisSpacing = 12.0;
    const topPadding = 12.0;
    const childAspectRatio = 0.52;

    final availableWidth =
        screenWidth - (horizontalPadding * 2) - crossAxisSpacing * (crossAxisCount - 1);
    final cardWidth = availableWidth / crossAxisCount;
    final cardHeight = cardWidth / childAspectRatio;
    final rowHeight = cardHeight + mainAxisSpacing;

    final scrollOffset = _scrollController.offset;

    final firstVisibleRow =
        ((scrollOffset - topPadding) / rowHeight).floor().clamp(0, 999999);
    final lastVisibleRow =
        ((scrollOffset - topPadding + screenHeight) / rowHeight).ceil().clamp(0, 999999);

    final indices = <int>[];
    for (int row = firstVisibleRow; row <= lastVisibleRow; row++) {
      for (int col = 0; col < crossAxisCount; col++) {
        final index = row * crossAxisCount + col;
        if (index >= 0 && index < _products.length) {
          indices.add(index);
        }
      }
    }
    return indices;
  }

  void _autoScrollRandomCard() {
    if (_products.isEmpty) return;

    final visibleIndices = _visibleProductIndices();
    if (visibleIndices.isEmpty) return;

    final eligible = visibleIndices
        .map((i) => _products[i])
        .where((p) => p.imageUrls.length > 1)
        .toList();

    if (eligible.isEmpty) return;

    final product = eligible[_random.nextInt(eligible.length)];
    final controller = _imagePageControllers[product.id];
    if (controller == null || !controller.hasClients) return;

    final imageCount = product.imageUrls.length;
    final currentIndex = _currentImageIndex[product.id]?.value ?? 0;
    final nextIndex = (currentIndex + 1) % imageCount;

    controller.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );

    _currentImageIndex[product.id]?.value = nextIndex;
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

      _syncPageControllers();
      _startAutoScrollTimer();
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

      _syncPageControllers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshProducts() async {
    _autoScrollTimer?.cancel();
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

  void _goToCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  Future<bool> _handleAddToCart(ShopifyProduct product, String variantId) async {
    if (_addingToCartProductIds.contains(product.id)) return false;

    setState(() => _addingToCartProductIds.add(product.id));

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final success = await CartService.instance.addLine(variantId: variantId);

    if (!mounted) return success;

    setState(() => _addingToCartProductIds.remove(product.id));

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
    return success;
  }

  void _showSizeSelector(ShopifyProduct product) {
    if (product.variants.isEmpty) return;

    String? selectedVariantId;
    bool isAdding = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selectedVariant = selectedVariantId == null
                ? null
                : product.variants
                    .firstWhere((v) => v.id == selectedVariantId);

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _fHead,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _priceBlock(product),
                  const SizedBox(height: 16),
                  const Text(
                    'SELECT SIZE',
                    style: TextStyle(
                      fontFamily: _fBold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      color: secondaryTxt,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: product.variants.map((variant) {
                      final bool available = variant.availableForSale;
                      final bool selected = variant.id == selectedVariantId;
                      return GestureDetector(
                        onTap: available
                            ? () => setSheetState(
                                () => selectedVariantId = variant.id)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? primary : Colors.transparent,
                            border: Border.all(
                              color: available
                                  ? primary
                                  : const Color(0xFFCCCCCC),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            variant.title,
                            style: TextStyle(
                              fontFamily: _fBold,
                              fontSize: 13,
                              color: selected
                                  ? Colors.white
                                  : available
                                      ? primary
                                      : const Color(0xFFBBBBBB),
                              decoration: available
                                  ? TextDecoration.none
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  if (selectedVariant != null)
                    Text(
                      selectedVariant.availableForSale
                          ? 'In stock'
                          : 'Out of stock',
                      style: TextStyle(
                        fontFamily: _fBody,
                        fontSize: 12,
                        color: selectedVariant.availableForSale
                            ? const Color(0xFF2E7D32)
                            : Colors.red,
                      ),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: (selectedVariantId == null || isAdding)
                          ? null
                          : () async {
                              setSheetState(() => isAdding = true);
                              final success = await _handleAddToCart(
                                  product, selectedVariantId!);
                              if (!sheetContext.mounted) return;
                              setSheetState(() => isAdding = false);
                              if (success) {
                                Navigator.pop(sheetContext);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primary.withOpacity(0.4),
                        shape: const RoundedRectangleBorder(),
                        elevation: 0,
                      ),
                      child: isAdding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'ADD TO CART',
                              style: TextStyle(
                                fontFamily: _fBold,
                                fontSize: 13,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                    fontFamily: _fBody,
                    fontSize: 10,
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
                  fontFamily: _fHead,
                  fontSize: 35,
                  color: primary,
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
                    fontFamily: _fBody,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: primary,
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
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w500,
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
                              fontFamily: _fBody,
                              fontSize: 16,
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
                                                  index == visibleValues.length) {
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

                                              final value = visibleValues[index];
                                              final isSelected = selected
                                                  .contains(value.input);

                                              return InkWell(
                                                onTap: () {
                                                  setSheetState(() {
                                                    final set = draft.putIfAbsent(
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
                                                        decoration: BoxDecoration(
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
                                                                color:
                                                                    Colors.white,
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
                  child: RichText(
                    text: TextSpan(
                      children: _priceSpans(
                        option.label,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: primary,
                      ),
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

  String _formatAmount(num amount) {
    final rounded = amount.round();
    final isNegative = rounded < 0;
    final str = rounded.abs().toString();

    if (str.length <= 3) return '${isNegative ? '-' : ''}$str';

    final lastThree = str.substring(str.length - 3);
    final rest = str.substring(0, str.length - 3);
    final restWithCommas = rest.replaceAllMapped(
      RegExp(r'\B(?=(\d{2})+(?!\d))'),
      (m) => ',',
    );
    return '${isNegative ? '-' : ''}$restWithCommas,$lastThree';
  }

  List<InlineSpan> _amountSpans({
    required num amount,
    required String currencyCode,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    final isInr = currencyCode.toUpperCase() == 'INR';
    final symbol = isInr ? '₹' : '$currencyCode ';
    final symbolFont = isInr ? _fRupee : _fBold;

    return [
      TextSpan(
        text: symbol,
        style: TextStyle(
          fontFamily: symbolFont,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          decoration: decoration,
          decorationColor: decorationColor,
        ),
      ),
      TextSpan(
        text: _formatAmount(amount),
        style: TextStyle(
          fontFamily: _fNumber,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          decoration: decoration,
          decorationColor: decorationColor,
        ),
      ),
    ];
  }

  List<InlineSpan> _priceSpans(
    String text, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    String? currentFont;

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(
        text: buffer.toString(),
        style: TextStyle(
          fontFamily: currentFont,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          decoration: decoration,
          decorationColor: decorationColor,
        ),
      ));
      buffer.clear();
    }

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final isRupeeSymbol = char == '₹';
      final isDigitOrSeparator = RegExp(r'[0-9,.]').hasMatch(char);

      final font = isRupeeSymbol
          ? _fRupee
          : isDigitOrSeparator
              ? _fNumber
              : _fBold;

      if (font != currentFont) {
        flush();
        currentFont = font;
      }
      buffer.write(char);
    }
    flush();

    return spans;
  }

  Widget _productCard(ShopifyProduct product) {
    final colorHexes = product.colorHexCodes;
    final controller = _imagePageControllers[product.id];
    final images = product.imageUrls.take(2).toList();
    final hasMultipleImages = images.length > 1;

    return _LongPressZoomCard(
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
      onLongPress: () => _showProductPeek(product),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasMultipleImages && controller != null)
                      PageView.builder(
                        controller: controller,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (index) {
                          _currentImageIndex[product.id]?.value = index;
                        },
                        itemCount: images.length,
                        itemBuilder: (_, idx) {
                          final url = images[idx];
                          return url != null
                              ? CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      Container(color: const Color(0xFFEEEEEE)),
                                  errorWidget: (_, __, ___) =>
                                      _imagePlaceholder(),
                                )
                              : _imagePlaceholder();
                        },
                      )
                    else
                      (product.primaryImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: product.primaryImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: const Color(0xFFEEEEEE)),
                              errorWidget: (_, __, ___) => _imagePlaceholder(),
                            )
                          : _imagePlaceholder()),
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
                            color: const Color.fromARGB(255, 194, 0, 0),
                          ),
                         child: RichText(
                            text: TextSpan(
                              children: _priceSpans(
                                _discountPercent(product),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (hasMultipleImages)
                      Positioned(
                        bottom: 6,
                        left: 0,
                        right: 0,
                        child: _imageDotIndicator(
                          product: product,
                          count: images.length,
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
                      fontFamily: _fBodyBold,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _priceBlock(product),
                  if (colorHexes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _colorSwatches(colorHexes),
                  ],
                  const SizedBox(height: 8),
                  _cartButtonForProduct(product),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductPeek(ShopifyProduct product) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: anim,
            child: _ProductPeekDialog(
              product: product,
              primary: primary,
              cardColor: cardColor,
              bgColor: bgColor,
              borderColor: borderColor,
              secondaryTxt: secondaryTxt,
              numberFont: _fNumber,
              rupeeFont: _fRupee,
              bodyFont: _fBold,
              onAddToCart: (variantId) async {
                Navigator.of(ctx).pop();
                final success =
                    await CartService.instance.addLine(variantId: variantId);
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(success
                        ? '${product.title} added to cart'
                        : 'Failed to add item to cart'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ));
              },
              onOpenDetail: () {
                Navigator.of(ctx).pop();
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
            ),
          ),
        );
      },
    );
  }

  Widget _imageDotIndicator({
    required ShopifyProduct product,
    required int count,
  }) {
    final notifier = _currentImageIndex[product.id];
    if (notifier == null) return const SizedBox.shrink();

    final dotCount = count.clamp(0, 5);

    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (_, currentIndex, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(dotCount, (i) {
            final isActive = i == currentIndex % dotCount;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: isActive ? 14 : 5,
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? primary : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _cartButtonForProduct(ShopifyProduct product) {
    return AnimatedBuilder(
      animation: CartService.instance,
      builder: (context, _) {
        final inCart =
            product.variants.any((v) => CartService.instance.isInCart(v.id));
        final isFilling = _fillAnimatingIds[product.id] ?? false;
        final isBusy = _addingToCartProductIds.contains(product.id);

        return SizedBox(
          width: double.infinity,
          height: 30,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: isFilling ? 1 : 0),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: value,
                          child: Container(color: primary),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: OutlinedButton(
                      onPressed: isBusy
                          ? null
                          : inCart
                              ? _goToCart
                              : () async {
                                  setState(() {
                                    _fillAnimatingIds[product.id] = true;
                                  });

                                  await Future.delayed(
                                    const Duration(milliseconds: 450),
                                  );

                                  if (!mounted) return;

                                  setState(() {
                                    _fillAnimatingIds[product.id] = false;
                                  });

                                  _showSizeSelector(product);
                                },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primary, width: 1.2),
                        shape: const RoundedRectangleBorder(),
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.transparent,
                        foregroundColor: isFilling ? Colors.white : primary,
                        disabledForegroundColor:
                            isFilling ? Colors.white : primary,
                      ),
                      child: Text(
                        inCart ? 'GO TO CART' : 'SHOP NOW',
                        style: TextStyle(
                          fontFamily: _fBodyBold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isFilling ? Colors.white : primary,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
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
      return RichText(
        text: TextSpan(
          children: _amountSpans(
            amount: product.price,
            currencyCode: product.currencyCode,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
      );
    }

    final saved = product.compareAtPrice! - product.price;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            RichText(
              text: TextSpan(
                children: _amountSpans(
                  amount: product.compareAtPrice!,
                  currencyCode: product.currencyCode,
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                  color: const Color(0xFF9A9A9A),
                  decoration: TextDecoration.lineThrough,
                  decorationColor: const Color(0xFF9A9A9A),
                ),
              ),
            ),
            const SizedBox(width: 6),
            RichText(
              text: TextSpan(
                children: _amountSpans(
                  amount: product.price,
                  currencyCode: product.currencyCode,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Save ',
                    style: TextStyle(
                      fontFamily: _fBold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromARGB(255, 53, 168, 59),
                    ),
                  ),
                  ..._amountSpans(
                    amount: saved,
                    currencyCode: product.currencyCode,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color.fromARGB(255, 53, 168, 59),
                  ),
                ],
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

class _LongPressZoomCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LongPressZoomCard({
    required this.child,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_LongPressZoomCard> createState() => _LongPressZoomCardState();
}

class _LongPressZoomCardState extends State<_LongPressZoomCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  Timer? _holdTimer;
  bool _longPressFired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _longPressFired = false;
    _ctrl.forward();
    _holdTimer = Timer(const Duration(milliseconds: 1000), () {
      _longPressFired = true;
      _ctrl.reverse();
      widget.onLongPress();
    });
  }

  void _onTapUp(TapUpDetails _) {
    _holdTimer?.cancel();
    _ctrl.reverse();
    if (!_longPressFired) widget.onTap();
  }

  void _onTapCancel() {
    _holdTimer?.cancel();
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

class _ProductPeekDialog extends StatefulWidget {
  final ShopifyProduct product;
  final Color primary;
  final Color cardColor;
  final Color bgColor;
  final Color borderColor;
  final Color secondaryTxt;
  final String numberFont;
  final String rupeeFont;
  final String bodyFont;
  final Future<void> Function(String variantId) onAddToCart;
  final VoidCallback onOpenDetail;

  const _ProductPeekDialog({
    required this.product,
    required this.primary,
    required this.cardColor,
    required this.bgColor,
    required this.borderColor,
    required this.secondaryTxt,
    required this.numberFont,
    required this.rupeeFont,
    required this.bodyFont,
    required this.onAddToCart,
    required this.onOpenDetail,
  });

  @override
  State<_ProductPeekDialog> createState() => _ProductPeekDialogState();
}

class _ProductPeekDialogState extends State<_ProductPeekDialog> {
  late final PageController _pageCtrl;
  int _currentPage = 0;
  String? _selectedVariantId;
  bool _isAddingToCart = false;

  List<_PeekOption> get _peekOptions {
    final product = widget.product;
    final result = <_PeekOption>[];

    for (final opt in product.options) {
      final name = opt.name.toUpperCase();
      if (name == 'COLOR' || name == 'COLOUR') continue;
      result.add(_PeekOption(
        label: opt.name,
        values: opt.values,
      ));
    }
    return result;
  }

  final Map<String, String> _selectedOptions = {};

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();

    final product = widget.product;
    if (product.variants.isNotEmpty) {
      final first = product.variants.first;
      _selectedVariantId = first.id;
      for (final so in first.selectedOptions) {
        _selectedOptions[so.name] = so.value;
      }
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _selectOption(String optionName, String value) {
    setState(() {
      _selectedOptions[optionName] = value;
    });
    for (final v in widget.product.variants) {
      final match = v.selectedOptions.every(
        (so) =>
            _selectedOptions[so.name] == null ||
            _selectedOptions[so.name] == so.value,
      );
      if (match) {
        setState(() => _selectedVariantId = v.id);
        break;
      }
    }
  }

  String _formatAmount(num amount) {
    final rounded = amount.round();
    final isNegative = rounded < 0;
    final str = rounded.abs().toString();

    if (str.length <= 3) return '${isNegative ? '-' : ''}$str';

    final lastThree = str.substring(str.length - 3);
    final rest = str.substring(0, str.length - 3);
    final restWithCommas = rest.replaceAllMapped(
      RegExp(r'\B(?=(\d{2})+(?!\d))'),
      (m) => ',',
    );
    return '${isNegative ? '-' : ''}$restWithCommas,$lastThree';
  }

  List<InlineSpan> _amountSpans({
    required num amount,
    required String currencyCode,
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    final isInr = currencyCode.toUpperCase() == 'INR';
    final symbol = isInr ? '₹' : '$currencyCode ';
    final symbolFont = isInr ? widget.rupeeFont : widget.bodyFont;

    return [
      TextSpan(
        text: symbol,
        style: TextStyle(
          fontFamily: symbolFont,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          decoration: decoration,
          decorationColor: decorationColor,
        ),
      ),
      TextSpan(
        text: _formatAmount(amount),
        style: TextStyle(
          fontFamily: widget.numberFont,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          decoration: decoration,
          decorationColor: decorationColor,
        ),
      ),
    ];
  }

  List<InlineSpan> _priceSpans(
    String text, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    String? currentFont;

    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(
        text: buffer.toString(),
        style: TextStyle(
          fontFamily: currentFont,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          decoration: decoration,
          decorationColor: decorationColor,
        ),
      ));
      buffer.clear();
    }

    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      final isRupeeSymbol = char == '₹';
      final isDigitOrSeparator = RegExp(r'[0-9,.]').hasMatch(char);

      final font = isRupeeSymbol
          ? widget.rupeeFont
          : isDigitOrSeparator
              ? widget.numberFont
              : widget.bodyFont;

      if (font != currentFont) {
        flush();
        currentFont = font;
      }
      buffer.write(char);
    }
    flush();

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product.imageUrls;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = screenWidth * 0.88;

    return Center(
      child: GestureDetector(
        onTap: widget.onOpenDetail,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: screenHeight * 0.82),
            decoration: BoxDecoration(
              color: widget.cardColor,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: dialogWidth * 1.1,
                    child: Stack(
                      children: [
                        PageView.builder(
                          controller: _pageCtrl,
                          itemCount: images.isEmpty ? 1 : images.length,
                          onPageChanged: (i) => setState(() => _currentPage = i),
                          itemBuilder: (_, i) {
                            if (images.isEmpty) {
                              return Container(color: const Color(0xFFEEEEEE));
                            }
                            return CachedNetworkImage(
                              imageUrl: images[i],
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: const Color(0xFFEEEEEE)),
                              errorWidget: (_, __, ___) =>
                                  Container(color: const Color(0xFFEEEEEE)),
                            );
                          },
                        ),
                        if (product.isOnSale)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD32F2F),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  children: _priceSpans(
                                    _discountPercent(product),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    color: Colors.white, size: 11),
                                SizedBox(width: 4),
                                Text(
                                  'View details',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (images.length > 1)
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                images.length.clamp(0, 8),
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  width: i == _currentPage ? 16 : 6,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: i == _currentPage
                                        ? widget.primary
                                        : Colors.white.withOpacity(0.65),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      color: widget.cardColor,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: widget.primary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _peekPriceRow(product),
                          const SizedBox(height: 12),
                          ..._peekOptions.map((opt) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _peekOptionRow(opt),
                              )),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton(
                              onPressed:
                                  _isAddingToCart || _selectedVariantId == null
                                      ? null
                                      : () async {
                                          setState(() => _isAddingToCart = true);
                                          await widget.onAddToCart(
                                              _selectedVariantId!);
                                        },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.primary,
                                shape: RoundedRectangleBorder(),
                                elevation: 0,
                              ),
                              child: _isAddingToCart
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'ADD TO CART',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _peekPriceRow(ShopifyProduct product) {
    if (!product.isOnSale) {
      return RichText(
        text: TextSpan(
          children: _amountSpans(
            amount: product.price,
            currencyCode: product.currencyCode,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: widget.primary,
          ),
        ),
      );
    }
    final saved = product.compareAtPrice! - product.price;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        RichText(
          text: TextSpan(
            children: _amountSpans(
              amount: product.compareAtPrice!,
              currencyCode: product.currencyCode,
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: const Color(0xFF9A9A9A),
              decoration: TextDecoration.lineThrough,
              decorationColor: const Color(0xFF9A9A9A),
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            children: _amountSpans(
              amount: product.price,
              currencyCode: product.currencyCode,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: widget.primary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
          ),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Save ',
                  style: TextStyle(
                    fontFamily: widget.bodyFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color.fromARGB(255, 84, 184, 89),
                  ),
                ),
                ..._amountSpans(
                  amount: saved,
                  currencyCode: product.currencyCode,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color.fromARGB(255, 84, 184, 89),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _peekOptionRow(_PeekOption opt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          opt.label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: widget.secondaryTxt,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: opt.values.map((val) {
            final isSelected = _selectedOptions[opt.label] == val;
            return GestureDetector(
              onTap: () => _selectOption(opt.label, val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? widget.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? widget.primary : widget.borderColor,
                    width: 1.2,
                  ),
                ),
                child: Text(
                  val,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : widget.primary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
}

class _PeekOption {
  final String label;
  final List<String> values;
  const _PeekOption({required this.label, required this.values});
}