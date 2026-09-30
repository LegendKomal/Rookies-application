import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/banner_model.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/home_content_models.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/screens/products/product_peek_dialog.dart';
import 'package:rookies_jeans/screens/products/products.dart';
import 'package:rookies_jeans/screens/search/search_tab_page.dart';
import 'package:rookies_jeans/services/cart_service.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';
import 'package:rookies_jeans/widget/wishlist_heart_button.dart';
import 'package:rookies_jeans/widget/sticker_chip.dart';

typedef R = Responsive;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static Color get primary => AppColors.primary;
  static Color get bgColor => AppColors.bg;
  static Color get secondaryTxt => AppColors.secondaryText;
  static const String _fHead = AppFonts.heading;
  static const String _fBody = AppFonts.body;
  static const String _fBold = AppFonts.bold;
  static const String _fNumber = AppFonts.number;

  // Fixed dark color for text/icons that sit on a hard-coded white
  // background (e.g. the hero CTA button). Using `primary` there breaks in
  // dark mode, where AppColors.primary becomes white -> white-on-white.
  static const Color _onLightBtn = Color(0xFF111111);

  static const double _kBottomNavHeight = 60.0;
  static const double _kBottomNavClearance = 84.0;

  static const String _heroMarqueeText = 'READY FOR MORE';
  static const String _heroSubtitle =
      'Renaisse redefines streetwear with bold silhouettes and clean essentials.';

  bool _isLoading = true;

  List<HomeBanner> _heroBanners = [];
  List<ExploreCategoryContent> _exploreCategories = [];
  List<PromoBlockContent> _promoBlocksContent = [];
  List<ShopTheLookEntry> _shopTheLookEntries = [];
  List<OccasionTileContent> _occasionTilesContent = [];
  List<FeatureBannerContent> _featureBanners = [];
  List<PriceTileContent> _priceTiles = [];

  /// "Shop by price" is a 2×2 grid: two tiles per row, two rows.
  static const int _kPriceTileColumns = 2;
  static const int _kPriceTileMax = 4;

  final ScrollController _scrollController = ScrollController();

  // "EXPLORE COLLECTIONS" section: a tab (its own collection) plus Shopify's
  // native "Category" and "Fit" facet filters on that collection, combinable
  // simultaneously, backed by an infinite-scrolling product grid.
  static const List<_ExploreTabDef> _exploreTabDefs = [
    _ExploreTabDef('HOT DEALS', ShopifyConstants.hotDealsHandle),
    _ExploreTabDef('SALE', 'mid-season-deals'),
    _ExploreTabDef('TRENDING NOW', ShopifyConstants.trendingNowHandle),
  ];

  int _exploreTabIndex = 0;
  ShopifyFilter? _exploreCategoryFilter;
  ShopifyFilter? _exploreFitFilter;
  String? _selectedExploreCategoryInput;
  String? _selectedExploreFitInput;
  int _exploreRequestId = 0;

  List<ShopifyProduct> _exploreProducts = [];
  String? _exploreEndCursor;
  bool _exploreHasMore = true;
  bool _exploreLoadingFirst = true;
  bool _exploreLoadingMore = false;

  final List<_ShopTheLookOutfit> _defaultShopTheLookOutfits = const [
    _ShopTheLookOutfit(
      imageAsset: 'assets/shop_the_look_outfit_1.jpg',
      products: [
        _ShopTheLookProduct(
          title: 'Black 100% Cotton Full Sleeve Oversized Solid Shirt',
          price: '₹ 1,899',
          imageAsset: 'assets/shop_the_look_item_1.jpg',
        ),
        _ShopTheLookProduct(
          title: 'White Balloon Fit Stretch Cargo Pants',
          price: '₹ 2,199',
          imageAsset: 'assets/shop_the_look_item_2.jpg',
        ),
      ],
    ),
    _ShopTheLookOutfit(
      imageAsset: 'assets/shop_the_look_outfit_2.jpg',
      products: [
        _ShopTheLookProduct(
          title: 'Product title',
          price: '₹ 20',
          imageAsset: 'assets/shop_the_look_item_1.jpg',
        ),
        _ShopTheLookProduct(
          title: 'Product title',
          price: '₹ 20',
          imageAsset: 'assets/shop_the_look_item_2.jpg',
        ),
      ],
    ),
    _ShopTheLookOutfit(
      imageAsset: 'assets/shop_the_look_outfit_3.jpg',
      products: [
        _ShopTheLookProduct(
          title: 'Product title',
          price: '₹ 20',
          imageAsset: 'assets/shop_the_look_item_3.jpg',
        ),
      ],
    ),
    _ShopTheLookOutfit(
      imageAsset: 'assets/shop_the_look_outfit_4.jpg',
      products: [
        _ShopTheLookProduct(
          title: 'Product title',
          price: '₹ 20',
          imageAsset: 'assets/shop_the_look_item_1.jpg',
        ),
        _ShopTheLookProduct(
          title: 'Product title',
          price: '₹ 20',
          imageAsset: 'assets/shop_the_look_item_2.jpg',
        ),
        _ShopTheLookProduct(
          title: 'Product title',
          price: '₹ 20',
          imageAsset: 'assets/shop_the_look_item_3.jpg',
        ),
      ],
    ),
  ];

  _ShopifyProductItem _mapShopifyProduct(ShopifyProduct product) {
    String? compareAtPrice;
    String? discountLabel;
    if (product.isOnSale) {
      final double comparePrice = product.compareAtPrice!;
      compareAtPrice = '₹ ${_formatInr(comparePrice)}';
      final int percentOff =
          (((comparePrice - product.price) / comparePrice) * 100).round();
      discountLabel = '-$percentOff%';
    }

    return _ShopifyProductItem(
      product: product,
      id: product.id,
      handle: product.handle,
      title: product.title,
      price: '₹ ${_formatInr(product.price)}',
      compareAtPrice: compareAtPrice,
      discountLabel: discountLabel,
      imageUrl: product.primaryImageUrl,
    );
  }

  String _formatInr(num amount) {
    final int rounded = amount.round();
    final bool negative = rounded < 0;
    String s = rounded.abs().toString();
    if (s.length <= 3) return (negative ? '-' : '') + s;

    final String last3 = s.substring(s.length - 3);
    String remaining = s.substring(0, s.length - 3);
    final List<String> groups = [last3];
    while (remaining.length > 2) {
      groups.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) groups.insert(0, remaining);
    return (negative ? '-' : '') + groups.join(',');
  }

  final List<_OccasionTile> _defaultOccasionTiles = const [
    _OccasionTile(imageAsset: 'assets/jeans_jann.jpeg', handle: 'jeans-jann'),
    _OccasionTile(imageAsset: 'assets/jeans_jesse.jpeg', handle: 'jeans-jesse'),
    _OccasionTile(
      imageAsset: 'assets/jeans_lennon.jpeg',
      handle: 'jeans-lennon',
    ),
    _OccasionTile(imageAsset: 'assets/jeans_mojo.jpeg', handle: 'jeans-mojo'),
    _OccasionTile(imageAsset: 'assets/jeans_nikki.jpeg', handle: 'jeans-nikki'),
    _OccasionTile(
      imageAsset: 'assets/jeans_springsteen.jpeg',
      handle: 'jeans-springsteen',
    ),
  ];

  final List<_PromoBlockData> _defaultPromoBlocks = const [
    _PromoBlockData(
      assetPath: 'assets/denim.png',
      label: 'Denim',
      buttonLabel: 'Explore',
      collectionHandle: 'JEANS',
    ),
    _PromoBlockData(
      assetPath: 'assets/cargo.png',
      label: 'Cargos',
      buttonLabel: 'Explore',
      collectionHandle: 'CARGOS',
    ),
    // _PromoBlockData(
    //   assetPath: 'assets/shoes.jpg',
    //   label: 'Shoes',
    //   buttonLabel: 'Shop Shoes',
    //   collectionHandle: 'shoes',P
    // ),
    // _PromoBlockData(
    //   assetPath: 'assets/accessories.jpg',
    //   label: 'Accessories',
    //   buttonLabel: 'Shop Accessories',
    //   collectionHandle: 'accessories',
    // ),
  ];

  String? get _heroBannerImageUrl {
    for (final banner in _heroBanners) {
      if (banner.imageUrl != null) return banner.imageUrl;
    }
    return null;
  }

  HomeBanner? get _primaryHeroBanner =>
      _heroBanners.isNotEmpty ? _heroBanners.first : null;

  void _openHeroCta() {
    final String? url = _primaryHeroBanner?.ctaUrl;
    if (url == null || url.isEmpty) return;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _openCollectionByHandle(url, label: _primaryHeroBanner?.ctaLabel);
    }
  }

  List<_PromoBlockData> get _promoBlocksToDisplay {
    if (_promoBlocksContent.isEmpty) return _defaultPromoBlocks;
    return _promoBlocksContent
        .map(
          (p) => _PromoBlockData(
            assetPath: null,
            imageUrl: p.imageUrl,
            label: p.label,
            buttonLabel: p.buttonLabel ?? 'Shop ${p.label}',
            collectionHandle: p.collectionHandle,
          ),
        )
        .toList();
  }

  List<_ShopTheLookOutfit> get _shopTheLookOutfitsToDisplay {
    if (_shopTheLookEntries.isEmpty) return _defaultShopTheLookOutfits;
    return _shopTheLookEntries
        .where((e) => e.imageUrl != null && e.products.isNotEmpty)
        .map(
          (e) => _ShopTheLookOutfit(
            imageAsset: 'assets/shop_the_look_outfit_1.jpg',
            imageUrl: e.imageUrl,
            products: e.products
                .map(
                  (p) => _ShopTheLookProduct(
                    title: p.title,
                    price: '₹ ${_formatInr(p.price)}',
                    imageAsset: 'assets/shop_the_look_item_1.jpg',
                    imageUrl: p.primaryImageUrl,
                    product: p,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  List<_OccasionTile> get _occasionTilesToDisplay {
    if (_occasionTilesContent.isEmpty) return _defaultOccasionTiles;
    return _occasionTilesContent
        .map(
          (t) => _OccasionTile(
            imageAsset: 'assets/jeans_jann.jpeg',
            imageUrl: t.imageUrl,
            handle: t.collectionHandle,
            label: t.label,
          ),
        )
        .toList();
  }

  List<_PromoBlockData> get _promoBlocksFirstHalf {
    return _promoBlocksToDisplay;
  }

  List<_PromoBlockData> get _promoBlocksSecondHalf {
    return const [];
  }

  List<Widget> _promoBlockSlivers(List<_PromoBlockData> blocks) {
    return blocks
        .map(
          (block) => SliverToBoxAdapter(
            child: _PromoBlockCard(
              assetPath: block.assetPath,
              imageUrl: block.imageUrl,
              label: block.label,
              buttonLabel: block.buttonLabel,
              height: _promoBlockHeight(context),
              onTap: () => _openCollectionByHandle(
                block.collectionHandle,
                title: block.label,
                label: block.label.toUpperCase(),
              ),
            ),
          ),
        )
        .toList();
  }

  /// Feature banners, stacked in the order they were added; same size as
  /// the Denim / Cargos promo blocks.
  List<Widget> _featureBannerSlivers() {
    return _featureBanners
        .map(
          (b) => SliverToBoxAdapter(
            child: _PromoBlockCard(
              imageUrl: b.imageUrl,
              label: b.label,
              buttonLabel: b.buttonLabel ?? '',
              height: _promoBlockHeight(context),
              onTap: () => _openLink(b.link, title: b.label),
            ),
          ),
        )
        .toList();
  }

  Widget _shopByPriceSection() {
    final r = R.of(context);
    final tiles = _priceTiles.take(_kPriceTileMax).toList();
    final double gap = r.dp(8);
    final rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += _kPriceTileColumns) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int j = 0; j < _kPriceTileColumns; j++) ...[
              if (j > 0) SizedBox(width: gap),
              Expanded(
                child: i + j < tiles.length
                    ? _priceTile(tiles[i + j])
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sliverHeadAsBox('SHOP BY PRICE'),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _priceTile(PriceTileContent tile) {
    return GestureDetector(
      onTap: () => _openLink(tile.link),
      // Full width at the image's own aspect ratio, so text baked into the
      // artwork ("SHOP UNDER ₹999") is never cropped.
      child: CachedNetworkImage(
        imageUrl: tile.imageUrl!,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        placeholder: (_, __) => AspectRatio(
          aspectRatio: 0.8,
          child: Container(color: const Color(0xFF555555)),
        ),
        errorWidget: (_, __, ___) => AspectRatio(
          aspectRatio: 0.8,
          child: Container(color: const Color(0xFF555555)),
        ),
      ),
    );
  }

  /// Opens a metaobject link: a collection handle, a `/collections/...` or
  /// `/products/...` path (full store URLs too), or any other web URL.
  void _openLink(String link, {String? title}) {
    final String url = link.trim();
    if (url.isEmpty) return;
    final String? name = (title == null || title.trim().isEmpty) ? null : title;

    final product = RegExp(r'/products/([^/?#]+)').firstMatch(url);
    if (product != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(
            handle: product.group(1)!,
            title: name ?? '',
          ),
        ),
      );
      return;
    }
    final collection = RegExp(r'/collections/([^/?#]+)').firstMatch(url);
    if (collection != null) {
      _openCollectionByHandle(collection.group(1)!, title: name);
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _openCollectionByHandle(url, title: name);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _fetchExploreProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll({bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoading = true);
    if (forceRefresh) {
      ShopifyStorefrontService.instance.clearCache();
    }
    final service = ShopifyStorefrontService.instance;
    final results = await Future.wait([
      service.getHomeBanners(),
      service.getExploreCategoriesContent(),
      service.getPromoBlocks(),
      service.getShopTheLookEntries(),
      service.getOccasionTilesContent(),
      service.getFeatureBanners(),
      service.getPriceTiles(),
    ]);
    if (!mounted) return;
    setState(() {
      _heroBanners = results[0] as List<HomeBanner>;
      _exploreCategories = results[1] as List<ExploreCategoryContent>;
      _promoBlocksContent = results[2] as List<PromoBlockContent>;
      _shopTheLookEntries = results[3] as List<ShopTheLookEntry>;
      _occasionTilesContent = results[4] as List<OccasionTileContent>;
      _featureBanners = results[5] as List<FeatureBannerContent>;
      _priceTiles = results[6] as List<PriceTileContent>;
      _isLoading = false;
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent - _exploreLoadMoreThreshold) {
      _loadMoreExploreProducts();
    }
  }

  double get _exploreLoadMoreThreshold {
    final r = R.of(context);
    final double gridWidth = MediaQuery.of(context).size.width - r.dp(16) * 2;
    final double cardWidth = (gridWidth - r.dp(12)) / 2;
    final double rowHeight = cardWidth / 0.62 + r.dp(16);
    // ~10 products at 2 columns per row = 5 rows.
    return rowHeight * 5;
  }

  List<String> get _exploreFilterInputs => [
    if (_selectedExploreCategoryInput != null) _selectedExploreCategoryInput!,
    if (_selectedExploreFitInput != null) _selectedExploreFitInput!,
  ];

  Future<void> _fetchExploreProducts() async {
    final int requestId = ++_exploreRequestId;
    setState(() {
      _exploreLoadingFirst = true;
      _exploreProducts = [];
      _exploreEndCursor = null;
      _exploreHasMore = true;
    });

    final String handle = _exploreTabDefs[_exploreTabIndex].handle;

    try {
      final response = await ShopifyStorefrontService.instance
          .getProductsByCollectionPaginated(
            handle,
            first: 20,
            filters: _exploreFilterInputs,
          );
      if (!mounted || requestId != _exploreRequestId) return;

      setState(() {
        _exploreProducts = response.products;
        _exploreEndCursor = response.endCursor;
        _exploreHasMore = response.hasNextPage;
        _exploreLoadingFirst = false;
        for (final filter in response.filters) {
          final label = filter.label.trim().toLowerCase();
          if (label == 'category') _exploreCategoryFilter = filter;
          if (label == 'fit') _exploreFitFilter = filter;
        }
      });
    } catch (e) {
      debugPrint('Failed to fetch explore products for "$handle": $e');
      if (!mounted || requestId != _exploreRequestId) return;
      setState(() => _exploreLoadingFirst = false);
    }
  }

  Future<void> _loadMoreExploreProducts() async {
    if (_exploreLoadingMore || !_exploreHasMore || _exploreLoadingFirst) return;

    final int requestId = _exploreRequestId;
    setState(() => _exploreLoadingMore = true);

    final String handle = _exploreTabDefs[_exploreTabIndex].handle;

    try {
      final response = await ShopifyStorefrontService.instance
          .getProductsByCollectionPaginated(
            handle,
            first: 20,
            after: _exploreEndCursor,
            filters: _exploreFilterInputs,
          );
      if (!mounted || requestId != _exploreRequestId) return;

      setState(() {
        _exploreProducts = [..._exploreProducts, ...response.products];
        _exploreEndCursor = response.endCursor;
        _exploreHasMore = response.hasNextPage;
        _exploreLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Failed to load more explore products for "$handle": $e');
      if (!mounted || requestId != _exploreRequestId) return;
      setState(() => _exploreLoadingMore = false);
    }
  }

  void _selectExploreTab(int index) {
    if (_exploreTabIndex == index) return;
    setState(() {
      _exploreTabIndex = index;
      _selectedExploreCategoryInput = null;
      _selectedExploreFitInput = null;
      _exploreCategoryFilter = null;
      _exploreFitFilter = null;
    });
    _fetchExploreProducts();
  }

  void _selectExploreCategory(ShopifyFilterValue? value) {
    if (_selectedExploreCategoryInput == value?.input) return;
    setState(() => _selectedExploreCategoryInput = value?.input);
    _fetchExploreProducts();
  }

  void _selectExploreFit(ShopifyFilterValue? value) {
    if (_selectedExploreFitInput == value?.input) return;
    setState(() => _selectedExploreFitInput = value?.input);
    _fetchExploreProducts();
  }

  void _openCollectionByHandle(String handle, {String? title, String? label}) {
    final collection = ShopifyCollection(
      id: handle,
      title: title ?? label ?? handle,
      handle: handle,
      label: label ?? (title ?? handle).toUpperCase(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductsPage(collection: collection)),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const SearchTabPage(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: _isLoading
              ? _shimmer()
              : Container(
                  color: bgColor,
                  child: RefreshIndicator(
                    color: primary,
                    onRefresh: _fetchAll,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _heroSection()),
                        ..._promoBlockSlivers(_promoBlocksFirstHalf),
                        SliverToBoxAdapter(
                          child: _sliverHeadAsBox('EXPLORE CATEGORIES'),
                        ),
                        SliverToBoxAdapter(child: _exploreCategoriesCarousel()),
                        ..._promoBlockSlivers(_promoBlocksSecondHalf),
                        ..._featureBannerSlivers(),
                        if (_priceTiles.isNotEmpty)
                          SliverToBoxAdapter(child: _shopByPriceSection()),
                        SliverToBoxAdapter(child: _shopTheLookSection()),
                        SliverToBoxAdapter(child: _shopByOccasionsSection()),
                        SliverToBoxAdapter(child: _exploreCollectionsSection()),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: _kBottomNavClearance),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  double _fullScreenBannerHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.size.height - mq.padding.top - mq.padding.bottom;
  }

  double _promoBlockHeight(BuildContext context) =>
      (MediaQuery.of(context).size.height * 0.46).clamp(220.0, 420.0);

  Widget _topBar() {
    final r = R.of(context);
    return SizedBox(
      height: r.dp(56),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.dp(8), vertical: r.dp(6)),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(Icons.search_rounded, size: r.dp(22)),
                  color: Colors.white,
                  onPressed: _openSearch,
                ),
              ),
            ),
            Image.asset(
              'assets/logo2.png',
              height: r.dp(14),
              fit: BoxFit.contain,
              color: Colors.white,
              colorBlendMode: BlendMode.srcIn,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.favorite_border_rounded, size: r.dp(22)),
                      color: Colors.white,
                      onPressed: () => context.push('/wishlist'),
                    ),
                    IconButton(
                      icon: Icon(Icons.person_outline_rounded, size: r.dp(22)),
                      color: Colors.white,
                      tooltip: 'Account',
                      onPressed: () => context.go('/profile'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroSection() {
    final r = R.of(context);
    return SizedBox(
      height: _fullScreenBannerHeight(context),
      width: double.infinity,
      child: Stack(
        children: [
          _heroBannerImage(),
          Positioned(top: 0, left: 0, right: 0, child: _topBar()),
          Positioned(
            left: 0,
            right: 0,
            bottom: r.dp(24),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 16),
                  child: child,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeroMarqueeText(
                    text: (_primaryHeroBanner?.title.isNotEmpty ?? false)
                        ? _primaryHeroBanner!.title
                        : _heroMarqueeText,
                    height: r.dp(44),
                  ),
                  SizedBox(height: r.dp(14)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.dp(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          (_primaryHeroBanner?.subtitle.isNotEmpty ?? false)
                              ? _primaryHeroBanner!.subtitle
                              : _heroSubtitle,
                          style: TextStyle(
                            fontFamily: _fBody,
                            fontSize: r.sp(13),
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(height: r.dp(14)),
                        GestureDetector(
                          onTap: _openHeroCta,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: r.dp(22),
                              vertical: r.dp(12),
                            ),
                            color: Colors.white,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _primaryHeroBanner?.ctaLabel ?? 'Shop now',
                                  style: TextStyle(
                                    fontFamily: _fBold,
                                    color: _onLightBtn,
                                    fontSize: r.sp(13),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: r.dp(6)),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: r.dp(16),
                                  color: _onLightBtn,
                                ),
                              ],
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
        ],
      ),
    );
  }

  Widget _heroBannerImage() => Stack(
    fit: StackFit.expand,
    children: [
      _heroBannerImageUrl != null
          ? CachedNetworkImage(
              imageUrl: _heroBannerImageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFF6B7A5E)),
              errorWidget: (_, __, ___) =>
                  Container(color: const Color(0xFF6B7A5E)),
            )
          : Image.asset(
              'assets/banner.jpeg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: const Color(0xFF6B7A5E)),
            ),
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withOpacity(0.28),
                  Colors.black.withOpacity(0.10),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.18, 0.38],
              ),
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withOpacity(0.60),
                  Colors.black.withOpacity(0.38),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.30, 0.58],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _sliverHeadAsBox(String title) {
    final r = R.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(26), r.dp(16), r.dp(12)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: _fHead,
            fontSize: r.sp(28),
            fontWeight: FontWeight.w600,
            color: primary,
          ),
        ),
      ),
    );
  }

  Widget _exploreCategoriesCarousel() {
    final r = R.of(context);
    if (_exploreCategories.isEmpty) return _empty();

    final double cardWidth = MediaQuery.of(context).size.width * 0.72;
    final double cardHeight = (cardWidth * 1.15).clamp(260.0, 380.0);

    final List<ExploreCategoryContent> topwear = _exploreCategories
        .where((c) => !c.isBottomwear)
        .toList();
    final List<ExploreCategoryContent> bottomwear = _exploreCategories
        .where((c) => c.isBottomwear)
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: r.dp(28)),
      child: Column(
        children: [
          if (topwear.isNotEmpty)
            _categoryRow(topwear, cardWidth, cardHeight, r),
          if (topwear.isNotEmpty && bottomwear.isNotEmpty)
            SizedBox(height: r.dp(10)),
          if (bottomwear.isNotEmpty)
            _categoryRow(bottomwear, cardWidth, cardHeight, r),
        ],
      ),
    );
  }

  Widget _categoryRow(
    List<ExploreCategoryContent> items,
    double cardWidth,
    double cardHeight,
    R r,
  ) {
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: r.dp(10)),
        itemBuilder: (_, i) {
          final cat = items[i];
          return _categoryCard(
            image: cat.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: cat.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFF555555)),
                    errorWidget: (_, __, ___) =>
                        Container(color: const Color(0xFF555555)),
                  )
                : Container(color: const Color(0xFF555555)),
            label: cat.label,
            width: cardWidth,
            height: cardHeight,
            onTap: () =>
                _openCollectionByHandle(cat.collectionHandle, label: cat.label),
            r: r,
          );
        },
      ),
    );
  }

  Widget _categoryCard({
    required Widget image,
    required String label,
    required double width,
    required double height,
    required VoidCallback onTap,
    required R r,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.45),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              left: r.dp(12),
              bottom: r.dp(12),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  color: Colors.white,
                  fontSize: r.sp(17),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openProductDetailFromExplore(_ShopifyProductItem product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          handle: product.handle,
          title: product.title,
          heroImageUrl: product.imageUrl,
        ),
      ),
    );
  }

  Widget _collectionProductCard(_ShopifyProductItem product, R r) {
    return GestureDetector(
      onTap: () => _openProductDetailFromExplore(product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: const Color(0xFFECECEC),
                  child: product.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const SizedBox(),
                          errorWidget: (_, __, ___) => const SizedBox(),
                        )
                      : Image.asset(
                          product.imageAssetFallback,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                ),
                if (product.discountLabel != null)
                  Positioned(
                    left: r.dp(8),
                    top: r.dp(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: r.dp(10),
                        vertical: r.dp(5),
                      ),
                      color: const Color(0xFFB3261E),
                      child: Text(
                        product.discountLabel!,
                        style: TextStyle(
                          fontFamily: _fBold,
                          color: Colors.white,
                          fontSize: r.sp(10),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (product.product != null)
                  Positioned(
                    top: r.dp(2),
                    right: r.dp(2),
                    child: WishlistHeartButton(product: product.product!),
                  ),
              ],
            ),
          ),
          SizedBox(height: r.dp(8)),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _fBody,
              fontSize: r.sp(12),
              color: primary,
              height: 1.25,
            ),
          ),
          SizedBox(height: r.dp(4)),
          Row(
            children: [
              Text(
                product.price,
                style: TextStyle(
                  fontFamily: _fNumber,
                  fontSize: r.sp(13),
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
              if (product.compareAtPrice != null) ...[
                SizedBox(width: r.dp(6)),
                Text(
                  product.compareAtPrice!,
                  style: TextStyle(
                    fontFamily: _fNumber,
                    fontSize: r.sp(12),
                    color: secondaryTxt,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _shopTheLookSection() {
    final double sectionHeight =
        _fullScreenBannerHeight(context) - _kBottomNavHeight;
    return SizedBox(
      height: sectionHeight,
      child: Column(
        children: [
          _sliverHeadAsBox('SHOP THE LOOK'),
          Expanded(child: _shopTheLookAsBox()),
        ],
      ),
    );
  }

  Widget _shopTheLookAsBox() {
    final List<_ShopTheLookOutfit> outfits = _shopTheLookOutfitsToDisplay;
    final int maxProducts = outfits
        .map((o) => o.products.length)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double available = constraints.maxHeight;
        final double usable = available.clamp(0.0, available);

        double heroHeight = usable * 0.55;
        heroHeight = heroHeight < 160.0 ? 160.0 : heroHeight;
        heroHeight = heroHeight > usable ? usable : heroHeight;

        final double remainingForRows = (usable - heroHeight).clamp(
          0.0,
          usable,
        );
        double productRowHeight = maxProducts > 0
            ? remainingForRows / maxProducts
            : 0.0;
        if (maxProducts > 0 && productRowHeight < 84.0) {
          productRowHeight = 84.0;
        }

        final double cardHeight =
            heroHeight + (productRowHeight * maxProducts);

        // Edge to edge: card spans the full screen width.
        return SizedBox(
          height: cardHeight,
          width: double.infinity,
          child: _ShopTheLookAutoSlideCard(
            outfits: outfits,
            heroHeight: heroHeight,
            productRowHeight: productRowHeight,
          ),
        );
      },
    );
  }

  Widget _shopByOccasionsSection() {
    final r = R.of(context);
    final double screenW = MediaQuery.of(context).size.width;

    // Portrait cards matching the 3:4 tile photos so the whole image fits
    // without cropping. One large column visible, with a generous peek of the
    // next one so it's clear the row scrolls.
    final double cardWidth = screenW * 0.62;
    final double cardHeight = cardWidth * 4 / 3;
    final double gap = r.dp(8); // horizontal gap between columns
    final double vGap = r.dp(8); // vertical gap between the two rows

    final tiles = _occasionTilesToDisplay;

    // Group tiles into vertical pairs. Each pair is ONE column (top + bottom
    // card) inside the SAME horizontal list, so both rows scroll together.
    final List<List<_OccasionTile>> pairs = [];
    for (int i = 0; i < tiles.length; i += 2) {
      pairs.add(
        tiles.sublist(i, (i + 2) > tiles.length ? tiles.length : i + 2),
      );
    }

    final double sectionHeight = cardHeight * 2 + vGap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(28), r.dp(16), 0),
          child: Text(
            'SHOP YOUR AESTHETICS',
            style: TextStyle(
              fontFamily: _fHead,
              fontSize: r.sp(22),
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
        SizedBox(height: r.dp(16)),
        if (pairs.isEmpty)
          _empty()
        else
          SizedBox(
            height: sectionHeight,
            child: _AutoScrollHorizontalList(
              itemCount: pairs.length,
              itemExtent: cardWidth + gap,
              padding: EdgeInsets.zero, // flush to the screen edges
              itemBuilder: (_, i) {
                final pair = pairs[i];
                return Padding(
                  padding: EdgeInsets.only(
                    right: i == pairs.length - 1 ? 0 : gap,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _occasionCard(pair[0], cardWidth, cardHeight, r),
                      if (pair.length > 1) ...[
                        SizedBox(height: vGap),
                        _occasionCard(pair[1], cardWidth, cardHeight, r),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        SizedBox(height: r.dp(20)),
      ],
    );
  }

  Widget _occasionCard(_OccasionTile tile, double width, double height, R r) {
    return GestureDetector(
      onTap: () => _openCollectionByHandle(tile.handle, label: tile.label),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            tile.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: tile.imageUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFFE0E0E0)),
                    errorWidget: (_, __, ___) =>
                        Container(color: const Color(0xFFE0E0E0)),
                  )
                : Image.asset(
                    tile.imageAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) =>
                        Container(color: const Color(0xFFE0E0E0)),
                  ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.35),
                  ],
                ),
              ),
            ),
            if (tile.label != null && tile.label!.trim().isNotEmpty)
              Positioned(
                left: r.dp(12),
                right: r.dp(12),
                bottom: r.dp(12),
                child: Text(
                  tile.label!.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _fHead,
                    fontSize: r.sp(18),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _exploreCollectionsSection() {
    final r = R.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: r.dp(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sliverHeadAsBox('EXPLORE COLLECTIONS'),
          _exploreTabsRow(r),
          SizedBox(height: r.dp(6)),
          _exploreCategoryChipsRow(r),
          if ((_exploreFitFilter?.values.isNotEmpty ?? false)) ...[
            SizedBox(height: r.dp(6)),
            _exploreFitChipsRow(r),
          ],
          SizedBox(height: r.dp(18)),
          _exploreProductGrid(r),
        ],
      ),
    );
  }

  Widget _exploreTabsRow(R r) {
    return StickerChipRow(
      height: 42,
      children: [
        for (int i = 0; i < _exploreTabDefs.length; i++)
          StickerChip(
            label: _exploreTabDefs[i].label,
            selected: i == _exploreTabIndex,
            style: StickerChipStyle.small,
            onTap: () => _selectExploreTab(i),
          ),
      ],
    );
  }

  Widget _exploreCategoryChipsRow(R r) {
    final values = _exploreCategoryFilter?.values ?? const [];
    if (values.isEmpty) return const SizedBox.shrink();

    return StickerChipRow(
      height: 60,
      children: [
        StickerChip(
          label: 'ALL',
          selected: _selectedExploreCategoryInput == null,
          style: StickerChipStyle.large,
          onTap: () => _selectExploreCategory(null),
        ),
        for (final value in values)
          StickerChip(
            label: value.label.toUpperCase(),
            selected: _selectedExploreCategoryInput == value.input,
            style: StickerChipStyle.large,
            onTap: () => _selectExploreCategory(value),
          ),
      ],
    );
  }

  Widget _exploreFitChipsRow(R r) {
    final values = _exploreFitFilter?.values ?? const [];
    return StickerChipRow(
      height: 40,
      children: [
        const StickerChipCaption('FIT & FABRIC'),
        StickerChip(
          label: 'ALL',
          selected: _selectedExploreFitInput == null,
          style: StickerChipStyle.mono,
          onTap: () => _selectExploreFit(null),
        ),
        for (final value in values)
          StickerChip(
            label: value.label.toUpperCase(),
            selected: _selectedExploreFitInput == value.input,
            style: StickerChipStyle.mono,
            onTap: () => _selectExploreFit(value),
          ),
      ],
    );
  }

  Widget _exploreProductGrid(R r) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_exploreLoadingFirst)
            Padding(
              padding: EdgeInsets.symmetric(vertical: r.dp(32)),
              child: Center(
                child: SizedBox(
                  width: r.dp(24),
                  height: r.dp(24),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
                ),
              ),
            )
          else if (_exploreProducts.isEmpty)
            _empty()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _exploreProducts.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: r.dp(16),
                crossAxisSpacing: r.dp(12),
                childAspectRatio: 0.62,
              ),
              itemBuilder: (_, i) => _collectionProductCard(
                _mapShopifyProduct(_exploreProducts[i]),
                r,
              ),
            ),
          if (_exploreLoadingMore)
            Padding(
              padding: EdgeInsets.symmetric(vertical: r.dp(20)),
              child: Center(
                child: SizedBox(
                  width: r.dp(20),
                  height: r.dp(20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shimmer() {
    final r = R.of(context);
    return Container(
      color: bgColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ShimmerBox(height: r.dp(420)),
          SizedBox(height: r.dp(2)),
          _ShimmerBox(height: r.dp(240)),
          SizedBox(height: r.dp(2)),
          _ShimmerBox(height: r.dp(240)),
          Padding(
            padding: EdgeInsets.all(r.dp(16)),
            child: _ShimmerBox(height: r.dp(14), width: r.dp(180)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
            child: _ShimmerBox(height: r.dp(260)),
          ),
          SizedBox(height: r.dp(16)),
          _ShimmerBox(height: r.dp(240)),
          SizedBox(height: r.dp(2)),
          _ShimmerBox(height: r.dp(240)),
          SizedBox(height: r.dp(16)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: r.dp(12),
              mainAxisSpacing: r.dp(16),
              childAspectRatio: 0.62,
              children: List.generate(
                4,
                (_) => _ShimmerBox(height: double.infinity),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    final r = R.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.dp(24), horizontal: r.dp(16)),
      child: Center(
        child: Text(
          'Nothing here yet.',
          style: TextStyle(
            fontFamily: _fBody,
            color: secondaryTxt,
            fontSize: r.sp(14),
          ),
        ),
      ),
    );
  }
}

class _HeroMarqueeText extends StatefulWidget {
  final String text;
  final double height;
  const _HeroMarqueeText({required this.text, required this.height});

  @override
  State<_HeroMarqueeText> createState() => _HeroMarqueeTextState();
}

class _HeroMarqueeTextState extends State<_HeroMarqueeText> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(milliseconds: 24), (_) {
      if (!mounted || !_controller.hasClients) return;
      final double max = _controller.position.maxScrollExtent;
      if (max <= 0) return;
      double next = _controller.offset + 1.4;
      if (next >= max) next = 0;
      _controller.jumpTo(next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final String unit = '${widget.text.toUpperCase()}        ';
    final String looped = List.filled(8, unit).join();
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ListView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Text(
            looped,
            maxLines: 1,
            style: TextStyle(
              fontFamily: AppFonts.heading,
              color: Colors.white,
              fontSize: r.sp(34),
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoBlockCard extends StatefulWidget {
  final String? assetPath;
  final String? imageUrl;
  final String label;
  final String buttonLabel;
  final double height;
  final VoidCallback onTap;
  const _PromoBlockCard({
    this.assetPath,
    this.imageUrl,
    required this.label,
    required this.buttonLabel,
    required this.height,
    required this.onTap,
  });

  @override
  State<_PromoBlockCard> createState() => _PromoBlockCardState();
}

class _PromoBlockCardState extends State<_PromoBlockCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: widget.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFF555555)),
                      errorWidget: (_, __, ___) =>
                          Container(color: const Color(0xFF555555)),
                    )
                  : Image.asset(
                      widget.assetPath ?? 'assets/denim.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFF555555)),
                    ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.45),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: r.dp(18),
                top: r.dp(20),
                child: Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    color: Colors.white,
                    fontSize: r.sp(32),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.buttonLabel.isNotEmpty)
                Positioned(
                right: r.dp(18),
                bottom: r.dp(20),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: r.dp(18),
                    vertical: r.dp(11),
                  ),
                  color: Colors.white,
                  child: Text(
                    widget.buttonLabel.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppFonts.bold,
                      color: const Color(0xFF111111),
                      fontSize: r.sp(12),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopifyProductItem {
  final String id;
  final String handle;
  final String title;
  final String price;
  final String? compareAtPrice;
  final String? discountLabel;
  final String? imageUrl;
  final String imageAssetFallback;
  /// Source product, when this item came from Shopify (needed for wishlist).
  final ShopifyProduct? product;
  const _ShopifyProductItem({
    this.product,
    required this.id,
    required this.handle,
    required this.title,
    required this.price,
    this.compareAtPrice,
    this.discountLabel,
    this.imageUrl,
    this.imageAssetFallback = 'assets/collection_cargo_olive.jpg',
  });
}

class _ShopTheLookOutfit {
  final String imageAsset;
  final String? imageUrl;
  final List<_ShopTheLookProduct> products;
  const _ShopTheLookOutfit({
    required this.imageAsset,
    this.imageUrl,
    required this.products,
  });
}

class _ShopTheLookAutoSlideCard extends StatefulWidget {
  final List<_ShopTheLookOutfit> outfits;
  final double heroHeight;
  final double productRowHeight;
  final Duration interval;
  const _ShopTheLookAutoSlideCard({
    required this.outfits,
    required this.heroHeight,
    required this.productRowHeight,
    this.interval = const Duration(seconds: 5),
  });

  @override
  State<_ShopTheLookAutoSlideCard> createState() =>
      _ShopTheLookAutoSlideCardState();
}

class _ShopTheLookAutoSlideCardState extends State<_ShopTheLookAutoSlideCard> {
  // Now follows the app theme instead of a fixed white/dark palette.
  // Matches the home screen background so the card blends into the page.
  Color get _cardBg => AppColors.bg;
  Color get _cardTextColor => AppColors.primary;
  Color get _cardBorder => AppColors.border;

  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    if (widget.outfits.length > 1) {
      _startAutoSlide();
    }
  }

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load every look's photo up front so sliding to the next one shows the
    // image immediately instead of an empty box that pops in.
    if (_precached) return;
    _precached = true;
    for (final outfit in widget.outfits) {
      final ImageProvider provider = outfit.imageUrl != null
          ? CachedNetworkImageProvider(outfit.imageUrl!)
          : AssetImage(outfit.imageAsset);
      precacheImage(provider, context, onError: (_, __) {});
    }
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      _index = (_index + 1) % widget.outfits.length;
      _controller.animateToPage(
        _index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  /// Pause auto-slide while the user drags, and restart the countdown when
  /// they let go, so a timer tick never yanks the page mid-swipe.
  bool _onScrollNotification(ScrollNotification n) {
    if (widget.outfits.length < 2) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _timer?.cancel();
    } else if (n is ScrollEndNotification) {
      if (_timer == null || !_timer!.isActive) _startAutoSlide();
    }
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _openProductDetail(BuildContext context, ShopifyProduct product) {
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
  }

  void _showQuickAddToCart(BuildContext context, ShopifyProduct product) {
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
              primary: AppColors.primary,
              onPrimary: AppColors.onPrimary,
              cardColor: AppColors.card,
              bgColor: AppColors.bg,
              borderColor: AppColors.border,
              secondaryTxt: AppColors.secondaryText,
              numberFont: AppFonts.number,
              rupeeFont: AppFonts.rupee,
              bodyFont: AppFonts.bold,
              onAddToCart: (variantId) async {
                Navigator.of(ctx).pop();
                final success = await CartService.instance.addLine(
                  variantId: variantId,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
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
              },
              onOpenDetail: () {
                Navigator.of(ctx).pop();
                _openProductDetail(context, product);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);

    if (widget.outfits.isEmpty) {
      return Container(color: const Color(0xFF555555));
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: _buildPages(r),
    );
  }

  Widget _buildPages(R r) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.outfits.length,
      onPageChanged: (i) => _index = i,
      itemBuilder: (_, i) {
        final outfit = widget.outfits[i];
        return Container(
          decoration: BoxDecoration(color: _cardBg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: widget.heroHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: _cardBg,
                      child: outfit.imageUrl != null
                          // No fade and a background-coloured placeholder, so
                          // a slide never flashes a dark box while the next
                          // photo loads.
                          ? CachedNetworkImage(
                              imageUrl: outfit.imageUrl!,
                              fit: BoxFit.contain,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholder: (_, __) => const SizedBox.expand(),
                              errorWidget: (_, __, ___) =>
                                  const SizedBox.expand(),
                            )
                          : Image.asset(
                              outfit.imageAsset,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.expand(),
                            ),
                    ),
                    // Positioned(
                    //   top: r.dp(12),
                    //   left: r.dp(12),
                    //   child: Container(
                    //     padding: EdgeInsets.symmetric(
                    //       horizontal: r.dp(10),
                    //       vertical: r.dp(5),
                    //     ),
                    //     color: Colors.white.withOpacity(0.92),
                    //     child: Text(
                    //       'LOOK ${i + 1}/${widget.outfits.length}',
                    //       style: TextStyle(
                    //         fontFamily: AppFonts.bold,
                    //         fontSize: r.sp(9.5),
                    //         letterSpacing: 0.6,
                    //         color: AppColors.primary,
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
              ...List.generate(outfit.products.length, (j) {
                final item = outfit.products[j];
                final ShopifyProduct? product = item.product;
                return SizedBox(
                  height: widget.productRowHeight,
                  child: GestureDetector(
                    onTap: product != null
                        ? () => _openProductDetail(context, product)
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: _cardBorder, width: 1),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: r.dp(12)),
                      child: Row(
                        children: [
                          Container(
                            width: r.dp(100),
                            height: r.dp(100),
                            color: const Color(0xFFECECEC),
                            child: item.imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: item.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const SizedBox(),
                                    errorWidget: (_, __, ___) =>
                                        const SizedBox(),
                                  )
                                : Image.asset(
                                    item.imageAsset,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(),
                                  ),
                          ),
                          SizedBox(width: r.dp(10)),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.bold,
                                    fontSize: r.sp(12),
                                    color: _cardTextColor,
                                  ),
                                ),
                                SizedBox(height: r.dp(2)),
                                Text(
                                  item.price,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppFonts.number,
                                    fontSize: r.sp(11),
                                    color: _cardTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: product != null
                                ? () => _showQuickAddToCart(context, product)
                                : null,
                            child: Container(
                              width: r.dp(26),
                              height: r.dp(26),
                              color: _cardTextColor.withOpacity(0.08),
                              child: Icon(
                                Icons.add_rounded,
                                size: r.dp(15),
                                color: _cardTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  const _ShimmerBox({required this.height, this.width, this.borderRadius});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double t = _controller.value;
          return ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(-1 - t * 2, 0),
              end: Alignment(1 - t * 2, 0),
              colors: const [
                Color(0xFFE7E7E7),
                Color(0xFFF6F6F6),
                Color(0xFFE7E7E7),
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(rect),
            child: Container(
              height: widget.height,
              width: widget.width,
              color: const Color(0xFFE7E7E7),
            ),
          );
        },
      ),
    );
  }
}

class _OccasionTile {
  final String imageAsset;
  final String? imageUrl;
  final String handle;
  final String? label;
  const _OccasionTile({
    required this.imageAsset,
    this.imageUrl,
    required this.handle,
    this.label,
  });
}

class _ShopTheLookProduct {
  final String title;
  final String price;
  final String imageAsset;
  final String? imageUrl;
  final ShopifyProduct? product;
  const _ShopTheLookProduct({
    required this.title,
    required this.price,
    required this.imageAsset,
    this.imageUrl,
    this.product,
  });
}

class _ExploreTabDef {
  final String label;
  final String handle;
  const _ExploreTabDef(this.label, this.handle);
}

class _PromoBlockData {
  final String? assetPath;
  final String? imageUrl;
  final String label;
  final String buttonLabel;
  final String collectionHandle;
  const _PromoBlockData({
    this.assetPath,
    this.imageUrl,
    required this.label,
    required this.buttonLabel,
    required this.collectionHandle,
  });
}

class _AutoScrollHorizontalList extends StatefulWidget {
  final int itemCount;
  final double itemExtent; // width of one item including its trailing gap
  final EdgeInsetsGeometry padding;
  final IndexedWidgetBuilder itemBuilder;
  final Duration interval;
  final Duration animationDuration;

  const _AutoScrollHorizontalList({
    required this.itemCount,
    required this.itemExtent,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.interval = const Duration(seconds: 5),
    this.animationDuration = const Duration(milliseconds: 600),
  });

  @override
  State<_AutoScrollHorizontalList> createState() =>
      _AutoScrollHorizontalListState();
}

class _AutoScrollHorizontalListState extends State<_AutoScrollHorizontalList> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.itemCount > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final double max = _controller.position.maxScrollExtent;
      if (max <= 0) return;

      final double next = _controller.offset + widget.itemExtent;
      if (next >= max) {
        _controller
            .animateTo(
              max,
              duration: widget.animationDuration,
              curve: Curves.easeInOut,
            )
            .then((_) {
              if (!mounted) return;
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted && _controller.hasClients) {
                  _controller.animateTo(
                    0,
                    duration: widget.animationDuration,
                    curve: Curves.easeInOut,
                  );
                }
              });
            });
      } else {
        _controller.animateTo(
          next,
          duration: widget.animationDuration,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _controller,
      padding: widget.padding,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      itemCount: widget.itemCount,
      itemBuilder: widget.itemBuilder,
    );
  }
}
