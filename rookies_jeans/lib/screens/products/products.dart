import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/screens/products/product_peek_dialog.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';
import 'package:rookies_jeans/services/cart_service.dart';
import 'package:rookies_jeans/widget/wishlist_heart_button.dart';

class _Responsive {
  _Responsive(BuildContext context) : _r = Responsive.of(context, baseW: 400);

  final Responsive _r;

  double get width => _r.width;
  double get height => _r.height;

  double get safeWidth => _r.safeWidth;

  bool get isTablet => _r.isTablet;
  bool get isDesktop => _r.isDesktop;

  double sp(double base) => _r.sp(base);
}

class ProductsPage extends StatefulWidget {
  /// The collection being browsed. Null in search mode.
  final ShopifyCollection? collection;

  /// When set, the page lists search results for this query instead of a
  /// collection — same banner, toolbar, grid and cards, so search results
  /// look and behave exactly like collection browsing.
  final String? searchQuery;

  /// Search mode only: called when the user jumps back to the dashboard, so
  /// the search tab it came from can clear its stale query/results (that
  /// tab's state otherwise survives bottom-nav navigation).
  final VoidCallback? onBackToDashboard;

  /// When set, the page auto-selects the "Fit" filter value matching this
  /// label (case-insensitive) as soon as the collection's filters load —
  /// used when arriving from a fit link like "Boxy fit" in Explore
  /// Categories so the product grid opens pre-filtered.
  final String? initialFitFilter;

  const ProductsPage({
    super.key,
    required ShopifyCollection this.collection,
    this.initialFitFilter,
  })  : searchQuery = null,
        onBackToDashboard = null;

  const ProductsPage.search({
    super.key,
    required String this.searchQuery,
    this.onBackToDashboard,
  })  : collection = null,
        initialFitFilter = null;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  static Color get primary => AppColors.primary;
  static Color get onPrimary => AppColors.onPrimary;
  static Color get bgColor => AppColors.bg;
  static Color get cardColor => AppColors.card;
  static Color get secondaryTxt => AppColors.secondaryText;
  static Color get borderColor => AppColors.border;

  static const double _kGridPadding = 12.0;
  static const double _kCrossSpacing = 4.0;
  static const double _kMainSpacing = 14.0;
  static const double _kCompactSpacing = 4.0;
  static const double _kAspect = 0.52;
  static const double _kToolbarHeight = 48.0;

  /// Products per row picked from the toolbar: 1 = large cards,
  /// 2 = standard cards, 3 = compact image-only tiles.
  int _gridMode = 2;

  bool get _isCompactGrid => _gridMode == 3;

  int _columnsFor(_Responsive r) {
    if (r.isDesktop) return _gridMode + 2;
    if (r.isTablet) return _gridMode + 1;
    return _gridMode;
  }

  double get _crossSpacing => _isCompactGrid ? _kCompactSpacing : _kCrossSpacing;
  double get _mainSpacing => _isCompactGrid ? _kCompactSpacing : _kMainSpacing;

  double _cardHeightFor(_Responsive r) {
    final columns = _columnsFor(r);
    final gridWidth = r.safeWidth - _kGridPadding * 2;
    final cardWidth = (gridWidth - _crossSpacing * (columns - 1)) / columns;
    switch (_gridMode) {
      case 1:
        // Portrait image plus the title / price / button block.
        return cardWidth * 1.25 + 120;
      case 3:
        return cardWidth / 0.75;
      default:
        return cardWidth / _kAspect;
    }
  }

  SliverGridDelegate _gridDelegate(_Responsive r) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _columnsFor(r),
      mainAxisSpacing: _mainSpacing,
      crossAxisSpacing: _crossSpacing,
      mainAxisExtent: _cardHeightFor(r),
    );
  }

  final ScrollController _scrollController = ScrollController();

  List<ShopifyProduct> _products = [];
  List<ShopifyFilter> _availableFilters = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  String? _endCursor;
  String? _error;

  static const String _fHead = AppFonts.heading;
  static const String _fBody = AppFonts.body;
  static const String _fAccent = AppFonts.accent;
  static const String _fBold = AppFonts.bold;
  static const String _fBodyBold = AppFonts.alteBold;
  static const String _fNumber = AppFonts.number;
  static const String _fRupee = AppFonts.rupee;

  ProductSortOption _sortOption = ProductSortOption.defaultSort;

  final Map<String, Set<String>> _selectedFilterInputs = {};
  final Map<String, bool> _expandedFilters = {};
  int _activeFilterSectionIndex = 0;
  bool _appliedInitialFitFilter = false;

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
    // Top banner is commented out (see build); its image isn't needed.
    // _fetchBannerImage();

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

    final r = _Responsive(context);
    final screenHeight = r.height;

    final crossAxisCount = _columnsFor(r);
    final rowHeight = _cardHeightFor(r) + _mainSpacing;

    // final topPadding = _bannerHeight(r) + _kToolbarHeight + _kGridPadding;
    final topPadding = _kToolbarHeight + _kGridPadding;
    final scrollOffset = _scrollController.offset;

    final firstVisibleRow =
        ((scrollOffset - topPadding) / rowHeight).floor().clamp(0, 999999);
    final lastVisibleRow = ((scrollOffset - topPadding + screenHeight) /
            rowHeight)
        .ceil()
        .clamp(0, 999999);

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

  List<ProductSortOption> get _availableSortOptions => ProductSortOption.values;

  bool get _isSearch => widget.searchQuery != null;

  /// Banner image loaded from Shopify (App Banner Image metafield, falling
  /// back to the collection image).
  String? _bannerImageUrl;

  // ignore: unused_element
  Future<void> _fetchBannerImage() async {
    if (_isSearch) return;
    final String? url = await ShopifyStorefrontService.instance
        .getCollectionBannerUrl(widget.collection!.handle);
    if (!mounted || url == null) return;
    setState(() => _bannerImageUrl = url);
  }

  String get _pageLabel => _isSearch
      ? '"${widget.searchQuery!.trim()}"'
      : widget.collection!.label;

  // Shopify's `search` only sorts server-side by RELEVANCE or PRICE, so in
  // search mode Newest / Title A-Z / Title Z-A are fetched by relevance and
  // re-sorted client-side over the loaded results.
  void _applySearchClientSort() {
    if (!_isSearch) return;
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

  Future<PaginatedProductsResponse> _fetchProducts({String? after}) {
    if (_isSearch) {
      final isPriceSort = _sortOption.shopifyKey == 'PRICE';
      return ShopifyStorefrontService.instance.searchProductsPaginated(
        widget.searchQuery!.trim(),
        first: 24,
        after: after,
        sortKey: isPriceSort ? 'PRICE' : 'RELEVANCE',
        reverse: isPriceSort && _sortOption.reverse,
        filters: _flatSelectedInputs,
      );
    }
    return ShopifyStorefrontService.instance.getProductsByCollectionPaginated(
      widget.collection!.handle,
      first: 24,
      after: after,
      sortKey: _sortOption.shopifyKey,
      reverse: _sortOption.reverse,
      filters: _flatSelectedInputs,
    );
  }

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
      final response = await _fetchProducts();

      if (!mounted) return;

      setState(() {
        _products = response.products;
        _applySearchClientSort();
        _hasNextPage = response.hasNextPage;
        _endCursor = response.endCursor;
        if (response.filters.isNotEmpty) {
          _availableFilters = response.filters;
        }
        _isLoading = false;
      });

      _syncPageControllers();
      _startAutoScrollTimer();

      if (_applyInitialFitFilterIfNeeded()) return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load products. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  /// Selects the "Fit" filter value matching [ProductsPage.initialFitFilter]
  /// (once, on first load) and refetches with it applied. Returns true when
  /// a refetch was kicked off, so the caller can skip its own state update
  /// for this pass — [_fetchInitialProducts] runs again and updates state.
  bool _applyInitialFitFilterIfNeeded() {
    if (_appliedInitialFitFilter) return false;
    _appliedInitialFitFilter = true;

    final wanted = widget.initialFitFilter?.trim().toLowerCase();
    if (wanted == null || wanted.isEmpty) return false;

    for (final filter in _availableFilters) {
      if (filter.label.trim().toLowerCase() != 'fit') continue;
      for (final value in filter.values) {
        if (value.label.trim().toLowerCase() == wanted) {
          setState(() {
            _selectedFilterInputs[filter.id] = {value.input};
          });
          _fetchInitialProducts();
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasNextPage) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _fetchProducts(after: _endCursor);

      if (!mounted) return;

      setState(() {
        _products.addAll(response.products);
        _applySearchClientSort();
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

  // ignore: unused_element
  double _bannerHeight(_Responsive r) {
    if (r.isDesktop) return 300;
    if (r.isTablet) return 265;
    return 220;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: bgColor,
        appBar: _listingAppBar(context),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: primary,
            onRefresh: _refreshProducts,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Top banner replaced by the app bar above.
                // _bannerWithToolbar(context),
                _pinnedToolbar(),
                if (_isLoading)
                  _shimmerSliverGrid()
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _errorState(),
                  )
                else if (_products.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(),
                  )
                else
                  _productSliverGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _listingAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      // Title sits right beside the back arrow (iOS would centre it).
      centerTitle: false,
      titleSpacing: 0,
      leadingWidth: 44,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: primary),
        onPressed: () => _goBack(context),
      ),
      title: Text(
        _pageLabel.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: _fHead, fontSize: 22, color: primary),
      ),
    );
  }

  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    // Search results can be the root of their tab; go back to the dashboard.
    widget.onBackToDashboard?.call();
    context.go('/home');
  }

  /// View / filter / sort toolbar, pinned under the app bar.
  Widget _pinnedToolbar() {
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      toolbarHeight: 0,
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_kToolbarHeight),
        child: _listingToolbar(context),
      ),
    );
  }

  /// The banner collapses and scrolls away as usual, while the view /
  /// filter / sort toolbar under it stays pinned just below the status bar
  /// once the banner is gone.
  // ignore: unused_element
  Widget _bannerWithToolbar(BuildContext context) {
    final r = _Responsive(context);
    final bannerHeight = _bannerHeight(r);
    final topInset = MediaQuery.of(context).padding.top;

    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      toolbarHeight: 0,
      expandedHeight: bannerHeight + _kToolbarHeight,
      backgroundColor: bgColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final bannerArea =
              (constraints.maxHeight - _kToolbarHeight).clamp(0.0, bannerHeight);
          final range = bannerHeight - topInset;
          final progress = range <= 0
              ? 1.0
              : (1 - (bannerArea - topInset) / range).clamp(0.0, 1.0);
          // Once collapsed only a status-bar-sized strip of the banner is
          // left; fade it into the page background so it doesn't show a
          // sliver of the image behind the status bar.
          final stripFade = ((progress - 0.85) / 0.15).clamp(0.0, 1.0);

          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: bannerArea,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: bannerHeight,
                    maxHeight: bannerHeight,
                    child: _banner(context, progress),
                  ),
                ),
              ),
              if (stripFade > 0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: bannerArea,
                  child: IgnorePointer(
                    child: ColoredBox(color: bgColor.withOpacity(stripFade)),
                  ),
                ),
            ],
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_kToolbarHeight),
        child: _listingToolbar(context),
      ),
    );
  }

  Widget _listingToolbar(BuildContext context) {
    final divider = SizedBox(
      height: 20,
      child: VerticalDivider(width: 1, thickness: 1, color: borderColor),
    );
    final labelStyle = TextStyle(
      fontFamily: _fBody,
      fontSize: 11,
      letterSpacing: 0.6,
      color: primary,
    );

    // View modes on the left; FILTER | SORT grouped on the right.
    return Container(
      height: _kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: Row(
        children: [
          _gridModeButton(1, Icons.view_agenda_sharp),
          const SizedBox(width: 6),
          _gridModeButton(2, Icons.grid_view_sharp),
          const SizedBox(width: 6),
          _gridModeButton(3, Icons.apps_sharp),
          const Spacer(),
          _toolbarAction(
            icon: Icons.filter_alt_outlined,
            label: _activeFilterCount > 0
                ? 'FILTER ($_activeFilterCount)'
                : 'FILTER',
            style: labelStyle,
            onTap: () => _openFilterSheet(context),
          ),
          divider,
          _toolbarAction(
            icon: Icons.swap_vert_rounded,
            label: 'SORT',
            style: labelStyle,
            onTap: () => _openSortSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _toolbarAction({
    required IconData icon,
    required String label,
    required TextStyle style,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: primary),
              const SizedBox(width: 6),
              Text(label, style: style),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridModeButton(int mode, IconData icon) {
    final isActive = _gridMode == mode;
    return InkWell(
      onTap: isActive ? null : () => setState(() => _gridMode = mode),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? primary : secondaryTxt.withOpacity(0.45),
        ),
      ),
    );
  }

  // `progress` is how far the banner has collapsed: 0 = fully expanded,
  // 1 = fully collapsed (its bottom edge has reached the top and the
  // sliver framework is about to hand scrolling over to the grid below).
  Widget _banner(BuildContext context, double progress) {
    final r = _Responsive(context);
    final bannerHeight = _bannerHeight(r);
    final titleSize = (r.width * 0.08).clamp(20.0, 36.0);
    // Shopify's App Banner Image (or collection image) wins over whatever
    // image the caller passed in, which is often none.
    final imageUrl = _bannerImageUrl ?? widget.collection?.imageUrl;

    // The text scrolls up and out first, over just the first slice of the
    // collapse — then, for the rest of the scroll, only the image is left
    // slowly decreasing from the bottom (the sliver's own shrink).
    const double textPhase = 0.35;
    final textProgress = (progress / textPhase).clamp(0.0, 1.0);
    final textFade = 1 - textProgress;
    final textShift = textProgress * 32;

    return SizedBox(
      height: bannerHeight,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // No transform here — the sliver itself shrinks the visible
          // extent from the bottom up as the user scrolls, so the image
          // decreases only from the bottom, never the sides or top.
          // Search results get a plain black banner, never an image.
          _isSearch
              ? Container(color: Colors.black)
              : imageUrl != null && imageUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.fieldFill),
                  errorWidget: (_, __, ___) => Container(color: primary),
                )
              : Container(color: primary),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.25 + progress * 0.15),
                  Colors.black.withOpacity(0.45 + progress * 0.15),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Opacity(
              opacity: textFade,
              child: Transform.translate(
                offset: Offset(0, -textShift),
                child: _breadcrumbNav(context),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Opacity(
              opacity: textFade,
              child: Transform.translate(
                offset: Offset(0, -textShift),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _pageLabel.toUpperCase(),
                      style: TextStyle(
                        fontFamily: _fHead,
                        fontSize: titleSize,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_isSearch && !_isLoading && _error == null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_products.length}${_hasNextPage ? '+' : ''} '
                        'RESULT${_products.length == 1 ? '' : 'S'}',
                        style: TextStyle(
                          fontFamily: _fBody,
                          fontSize: 12,
                          letterSpacing: 0.6,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breadcrumbNav(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            if (_isSearch) {
              widget.onBackToDashboard?.call();
              Navigator.of(context).popUntil((r) => r.isFirst);
              context.go('/home');
              return;
            }
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
          child: Text(
            'HOME',
            style: TextStyle(
              fontFamily: _fBody,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: Colors.white.withOpacity(0.75),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: Colors.white.withOpacity(0.75),
          ),
        ),
        Flexible(
          child: Text(
            _isSearch ? 'SEARCH' : widget.collection!.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _fBold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _productSliverGrid() {
    final r = _Responsive(context);
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        _kGridPadding,
        _kGridPadding,
        _kGridPadding,
        90,
      ),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate(r),
        delegate: SliverChildBuilderDelegate(
          (_, i) {
            if (i >= _products.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return _isCompactGrid
                ? _compactProductCard(_products[i])
                : _productCard(_products[i]);
          },
          childCount: _products.length + (_isLoadingMore ? 1 : 0),
        ),
      ),
    );
  }


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
              maxWidth: 640,
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primary,
                      ),
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
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w500,
                            color: primary,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_rounded, color: primary)
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
        final r = _Responsive(sheetContext);
        final railWidth = (r.width * 0.32).clamp(96.0, 200.0);
        // Whole filter sheet renders in Archivo at w900 (Archivo Black weight).
        return DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: _fBody, fontWeight: FontWeight.w900),
          child: StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final draftActiveCount =
                draft.values.fold<int>(0, (sum, s) => sum + s.length);

            if (_visibleFilters.isEmpty) {
              return SafeArea(
                child: SizedBox(
                  height: 320,
                  child: Center(
                    child: Text(
                      _isSearch
                          ? 'No filters available for this search.'
                          : 'No filters available for this collection.',
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
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 900),
                child: SizedBox(
                  height: r.height * (r.height < 600 ? 0.92 : 0.82),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Row(
                          children: [
                            Text(
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
                              child: Text(
                                'Clear All',
                                style: TextStyle(
                                  fontFamily: _fBody,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: primary,
                                ),
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
                                                fontWeight: FontWeight.w900,
                                                color: primary,
                                              ),
                                            ),
                                          ),
                                          if (count > 0)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                padding:
                                    const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeFilter.label,
                                      style: TextStyle(
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
                                                  Divider(
                                                height: 1,
                                                color: borderColor,
                                              ),
                                              itemBuilder: (context, index) {
                                                if (canShowMore &&
                                                    index ==
                                                        visibleValues.length) {
                                                  return InkWell(
                                                    onTap: () {
                                                      setSheetState(() {
                                                        _expandedFilters[
                                                                activeFilter
                                                                    .id] =
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
                                                        style: TextStyle(
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
                                                      final set =
                                                          draft.putIfAbsent(
                                                        activeFilter.id,
                                                        () => <String>{},
                                                      );
                                                      if (isSelected) {
                                                        set.remove(
                                                            value.input);
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
                                                                    .circular(
                                                                        4),
                                                            color: isSelected
                                                                ? primary
                                                                : Colors
                                                                    .transparent,
                                                          ),
                                                          child: isSelected
                                                              ? Icon(
                                                                  Icons.check,
                                                                  size: 13,
                                                                  color:
                                                                      onPrimary,
                                                                )
                                                              : null,
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            value.label,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: primary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ),
                                                        if (value.count > 0)
                                                          Text(
                                                            '${value.count}',
                                                            style: TextStyle(
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
                        decoration: BoxDecoration(
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
                                  side: BorderSide(color: primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontFamily: _fBody,
                                    color: primary,
                                    fontWeight: FontWeight.w900,
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
                                  foregroundColor: onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                child: Text(
                                  draftActiveCount > 0
                                      ? 'Apply ($draftActiveCount)'
                                      : 'Apply',
                                  style: TextStyle(
                                    fontFamily: _fBody,
                                    color: onPrimary,
                                    fontWeight: FontWeight.w900,
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
              ),
            );
          },
          ),
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
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: borderColor,
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
                    color: isSelected ? primary : cardColor,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          size: 13,
                          color: onPrimary,
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
                          return CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: const Color(0xFFEEEEEE)),
                            errorWidget: (_, __, ___) => _imagePlaceholder(),
                          );
                        },
                      )
                    else
                      (product.primaryImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: product.primaryImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: AppColors.fieldFill),
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
                          child: Text(
                            _discountPercent(product),
                            style: const TextStyle(
                              fontFamily: _fAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: WishlistHeartButton(
                        product: product,
                        size: 16,
                        idleColor: Colors.black,
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
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _fBodyBold,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _priceBlock(product),
                  if (colorHexes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _colorSwatches(colorHexes),
                  ],
                ],
              ),
            ),
          ],
      ),
    );
  }

  /// Image-only tile for the 3-per-row view: no title, price or button.
  Widget _compactProductCard(ShopifyProduct product) {
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          product.primaryImageUrl != null
              ? CachedNetworkImage(
                  imageUrl: product.primaryImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: AppColors.fieldFill),
                  errorWidget: (_, __, ___) => _imagePlaceholder(),
                )
              : _imagePlaceholder(),
          if (product.isOnSale)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                color: const Color.fromARGB(255, 194, 0, 0),
                child: Text(
                  _discountPercent(product),
                  style: const TextStyle(
                    fontFamily: _fAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 0,
            right: 0,
            child: WishlistHeartButton(
              product: product,
              size: 13,
              idleColor: Colors.black,
            ),
          ),
        ],
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
            child: ProductPeekDialog(
              product: product,
              primary: primary,
              onPrimary: AppColors.onPrimary,
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

  Widget _imagePlaceholder() => Container(
        color: AppColors.fieldFill,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.hint,
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

    // final saved = product.compareAtPrice! - product.price;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 2,
      children: [
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
        // "Save ₹X" hidden on product cards.
        // RichText(
          // text: TextSpan(
            // children: [
              // TextSpan(
                // text: 'Save ',
                // style: TextStyle(
                  // fontFamily: _fBold,
                  // fontSize: 11,
                  // fontWeight: FontWeight.w600,
                  // color: const Color.fromARGB(255, 53, 168, 59),
                // ),
              // ),
              // ..._amountSpans(
                // amount: saved,
                // currencyCode: product.currencyCode,
                // fontSize: 11,
                // fontWeight: FontWeight.w600,
                // color: const Color.fromARGB(255, 53, 168, 59),
              // ),
            // ],
          // ),
        // ),
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
    return '-$pct%';
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: AppColors.hint,
            ),
            const SizedBox(height: 14),
            Text(
              _isSearch ? 'No results for $_pageLabel' : 'No products found',
              textAlign: TextAlign.center,
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
                  : _isSearch
                      ? 'Try a different search term.'
                      : 'Check back soon for new arrivals.',
              style: TextStyle(fontSize: 12, color: secondaryTxt),
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
                style: TextStyle(fontSize: 13, color: secondaryTxt),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _fetchInitialProducts,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('RETRY'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _shimmerSliverGrid() {
    final r = _Responsive(context);
    return SliverPadding(
      padding: const EdgeInsets.all(_kGridPadding),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate(r),
        delegate: SliverChildBuilderDelegate(
          (_, __) => Container(
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
            ),
          ),
          childCount: _columnsFor(r) * 3,
        ),
      ),
    );
  }
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

