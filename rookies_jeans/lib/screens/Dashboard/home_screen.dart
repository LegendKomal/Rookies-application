import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/models/banner_model.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/home_content_models.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/screens/products/product_peek_dialog.dart';
import 'package:rookies_jeans/screens/products/products.dart';
import 'package:rookies_jeans/screens/search/search.dart';
import 'package:rookies_jeans/services/cart_service.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';

typedef R = Responsive;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static Color get primary      => AppColors.primary;
  static Color get onPrimary    => AppColors.onPrimary;
  static Color get bgColor      => AppColors.bg;
  static Color get cardColor    => AppColors.card;
  static Color get borderColor  => AppColors.border;
  static Color get secondaryTxt => AppColors.secondaryText;
  static const String _fHead   = AppFonts.heading;
  static const String _fBody   = AppFonts.body;
  static const String _fBold   = AppFonts.bold;
  static const String _fNumber = AppFonts.number;

  static const double _kBottomNavHeight = 60.0;
  static const double _kBottomNavClearance = 84.0;
  static const double _kSectionGap = 24.0;

  static const String _heroMarqueeText = 'READY FOR MORE';
  static const String _heroSubtitle =
      'Renaisse redefines streetwear with bold silhouettes and clean essentials.';

  bool _isLoading = true;

  List<HomeBanner> _heroBanners = [];
  List<ExploreCategoryContent> _exploreCategories = [];
  List<PromoBlockContent> _promoBlocksContent = [];
  List<ShopTheLookEntry> _shopTheLookEntries = [];
  List<OccasionTileContent> _occasionTilesContent = [];
  List<InstagramPostContent> _instagramPostsContent = [];

  final ScrollController _scrollController = ScrollController();

  _CollectionTab _selectedCollectionTab = _CollectionTab.newArrivals;

  final Map<_CollectionTab, List<_ShopifyProductItem>> _collectionProductsByTab = {
    _CollectionTab.newArrivals: [],
    _CollectionTab.bestsellers: [],
    _CollectionTab.sale: [],
  };
  final Map<_CollectionTab, String?> _collectionCursorByTab = {
    _CollectionTab.newArrivals: null,
    _CollectionTab.bestsellers: null,
    _CollectionTab.sale: null,
  };
  final Map<_CollectionTab, bool> _collectionHasMoreByTab = {
    _CollectionTab.newArrivals: true,
    _CollectionTab.bestsellers: true,
    _CollectionTab.sale: true,
  };
  bool _isLoadingCollectionProducts = false;

  Future<void> _loadMoreCollectionProducts(_CollectionTab tab) async {
    if (_isLoadingCollectionProducts) return;
    if (_collectionHasMoreByTab[tab] == false) return;

    setState(() => _isLoadingCollectionProducts = true);
    try {
      final page = await _fetchProductsPage(tab, after: _collectionCursorByTab[tab]);
      if (!mounted) return;
      setState(() {
        _collectionProductsByTab[tab] = [
          ...?_collectionProductsByTab[tab],
          ...page.items,
        ];
        _collectionCursorByTab[tab] = page.endCursor;
        _collectionHasMoreByTab[tab] = page.hasNextPage;
      });
    } finally {
      if (mounted) setState(() => _isLoadingCollectionProducts = false);
    }
  }

  Future<_ProductsPage> _fetchProductsPage(_CollectionTab tab, {String? after}) async {
    final String handle = _collectionHandleForTab(tab);
    try {
      final PaginatedProductsResponse response = await ShopifyStorefrontService
          .instance
          .getProductsByCollectionPaginated(
        handle,
        first: 6,
        after: after,
      );

      return _ProductsPage(
        items: response.products.map(_mapShopifyProduct).toList(),
        endCursor: response.endCursor,
        hasNextPage: response.hasNextPage,
      );
    } catch (e) {
      debugPrint('Failed to fetch products for "$handle": $e');
      return const _ProductsPage(items: [], endCursor: null, hasNextPage: false);
    }
  }

  _ShopifyProductItem _mapShopifyProduct(ShopifyProduct product) {
    String? compareAtPrice;
    String? discountLabel;
    if (product.isOnSale) {
      final double comparePrice = product.compareAtPrice!;
      compareAtPrice = '₹ ${_formatInr(comparePrice)}';
      final int percentOff =
          (((comparePrice - product.price) / comparePrice) * 100).round();
      discountLabel = '$percentOff% OFF';
    }

    return _ShopifyProductItem(
      id: product.id,
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

  String _collectionHandleForTab(_CollectionTab tab) {
    switch (tab) {
      case _CollectionTab.newArrivals:
        return 'summer-edit';
      case _CollectionTab.bestsellers:
        return 'trending-now';
      case _CollectionTab.sale:
        return 'mid-season-deals';
    }
  }

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
    if (_promoBlocksContent.isEmpty) return const [];
    return _promoBlocksContent
        .map((p) => _PromoBlockData(
              imageUrl: p.imageUrl,
              label: p.label,
              buttonLabel: p.buttonLabel ?? 'Shop ${p.label}',
              collectionHandle: p.collectionHandle,
            ))
        .toList();
  }

  List<_ShopTheLookOutfit> get _shopTheLookOutfitsToDisplay {
    if (_shopTheLookEntries.isEmpty) return const [];
    return _shopTheLookEntries
        .where((e) => e.imageUrl != null && e.products.isNotEmpty)
        .map((e) => _ShopTheLookOutfit(
              imageUrl: e.imageUrl,
              products: e.products
                  .map((p) => _ShopTheLookProduct(
                        title: p.title,
                        price: '₹ ${_formatInr(p.price)}',
                        imageUrl: p.primaryImageUrl,
                        product: p,
                      ))
                  .toList(),
            ))
        .toList();
  }

  List<_OccasionTile> get _occasionTilesToDisplay {
    if (_occasionTilesContent.isEmpty) return const [];
    return _occasionTilesContent
        .map((t) => _OccasionTile(
              imageUrl: t.imageUrl,
              handle: t.collectionHandle,
              label: t.label,
            ))
        .toList();
  }

  List<_InstagramPost> get _instagramPostsToDisplay {
    if (_instagramPostsContent.isEmpty) return const [];
    return _instagramPostsContent
        .map((p) => _InstagramPost(
              imageUrl: p.imageUrl,
              postUrl: p.postUrl,
              username: p.username,
            ))
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
        .map((block) => SliverToBoxAdapter(
              child: _PromoBlockCard(
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
            ))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _loadMoreCollectionProducts(_selectedCollectionTab);
  }

  @override
  void dispose() {
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
      service.getInstagramPostsContent(),
    ]);
    if (!mounted) return;
    setState(() {
      _heroBanners = results[0] as List<HomeBanner>;
      _exploreCategories = results[1] as List<ExploreCategoryContent>;
      _promoBlocksContent = results[2] as List<PromoBlockContent>;
      _shopTheLookEntries = results[3] as List<ShopTheLookEntry>;
      _occasionTilesContent = results[4] as List<OccasionTileContent>;
      _instagramPostsContent = results[5] as List<InstagramPostContent>;
      _isLoading = false;
    });
  }

  void _openCollectionByHandle(String handle,
      {String? title, String? label}) {
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
        pageBuilder: (_, animation, __) => const SearchPage(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _openInstagramPost(String url) async {
  if (url.isEmpty) return;
  final Uri uri = Uri.parse(url);
  try {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Instagram link')),
      );
    }
  } catch (e) {
    debugPrint('Failed to launch $url: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Instagram link')),
      );
    }
  }
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
                      SliverToBoxAdapter(child: _exploreCollectionSection()),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: _kSectionGap),
                      ),
                      SliverToBoxAdapter(child: _shopTheLookSection()),
                      SliverToBoxAdapter(child: _shopByOccasionsSection()),
                      SliverToBoxAdapter(
                        child: _sliverCenteredHeadAsBox('FOLLOW US @ROOKIESJEANS'),
                      ),
                      SliverToBoxAdapter(child: _instagramList()),
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
        padding: EdgeInsets.symmetric(
          horizontal: r.dp(8),
          vertical: r.dp(6),
        ),
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
                      icon: Icon(Icons.favorite_border_rounded,
                          size: r.dp(22)),
                      color: Colors.white,
                      onPressed: () => context.go('/wishlist'),
                    ),
                    IconButton(
                      icon: Icon(Icons.person_outline_rounded,
                          size: r.dp(22)),
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _topBar(),
          ),
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
                                    color: Colors.black,
                                    fontSize: r.sp(13),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: r.dp(6)),
                                Icon(Icons.arrow_forward_rounded,
                                    size: r.dp(16), color: Colors.black),
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
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFF6B7A5E)),
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFF6B7A5E)),
                )
              : Container(color: const Color(0xFF6B7A5E)),
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

  Widget _sliverCenteredHeadAsBox(String title) {
    final r = R.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(40), r.dp(16), r.dp(16)),
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

    final double cardWidth = MediaQuery.of(context).size.width * 0.56;
    final double cardHeight = cardWidth.clamp(190.0, 260.0);

    final List<ExploreCategoryContent> topwear =
        _exploreCategories.where((c) => !c.isBottomwear).toList();
    final List<ExploreCategoryContent> bottomwear =
        _exploreCategories.where((c) => c.isBottomwear).toList();

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

  Widget _categoryRow(List<ExploreCategoryContent> items, double cardWidth,
      double cardHeight, R r) {
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
            onTap: () => _openCollectionByHandle(
              cat.collectionHandle,
              label: cat.label,
            ),
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

  Widget _exploreCollectionSection() {
    final r = R.of(context);
    final List<_ShopifyProductItem> products =
        _collectionProductsByTab[_selectedCollectionTab] ?? const [];
    final bool hasMore = _collectionHasMoreByTab[_selectedCollectionTab] ?? false;
    final bool loadingFirstPage =
        products.isEmpty && _isLoadingCollectionProducts;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: r.dp(28)),
          Text(
            'EXPLORE COLLECTION',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _fHead,
              fontSize: r.sp(24),
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
          SizedBox(height: r.dp(16)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _collectionTabChip('NEW ARRIVALS', _CollectionTab.newArrivals, r),
              SizedBox(width: r.dp(8)),
              _collectionTabChip('BESTSELLERS', _CollectionTab.bestsellers, r),
              SizedBox(width: r.dp(8)),
              _collectionTabChip('SALE', _CollectionTab.sale, r),
            ],
          ),
          SizedBox(height: r.dp(20)),
          if (loadingFirstPage)
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
          else if (products.isEmpty)
            _empty()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent:
                    r.isDesktop ? 260 : (r.isTablet ? 240 : 200),
                mainAxisSpacing: r.dp(16),
                crossAxisSpacing: r.dp(12),
                childAspectRatio: 0.62,
              ),
              itemBuilder: (_, i) => _collectionProductCard(products[i], r),
            ),
          if (hasMore) ...[
            SizedBox(height: r.dp(20)),
            GestureDetector(
              onTap: _isLoadingCollectionProducts
                  ? null
                  : () => _loadMoreCollectionProducts(_selectedCollectionTab),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: r.dp(14)),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: (_isLoadingCollectionProducts && products.isNotEmpty)
                    ? SizedBox(
                        width: r.dp(18),
                        height: r.dp(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: onPrimary,
                        ),
                      )
                    : Text(
                        'Show More',
                        style: TextStyle(
                          fontFamily: _fBold,
                          color: onPrimary,
                          fontSize: r.sp(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
          SizedBox(height: r.dp(8)),
        ],
      ),
    );
  }

  Widget _collectionTabChip(String label, _CollectionTab tab, R r) {
    final bool selected = _selectedCollectionTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCollectionTab = tab);
        if ((_collectionProductsByTab[tab] ?? const []).isEmpty) {
          _loadMoreCollectionProducts(tab);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.dp(14), vertical: r.dp(9)),
        decoration: BoxDecoration(
          color: selected ? primary : cardColor,
          border: Border.all(color: primary, width: 1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: _fBold,
            fontSize: r.sp(11),
            fontWeight: FontWeight.w600,
            color: selected ? onPrimary : primary,
          ),
        ),
      ),
    );
  }

  Widget _collectionProductCard(_ShopifyProductItem product, R r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: AppColors.fieldFill,
                child: product.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(),
                        errorWidget: (_, __, ___) => const SizedBox(),
                      )
                    : const SizedBox(),
              ),
              if (product.discountLabel != null)
                Positioned(
                  left: r.dp(8),
                  top: r.dp(8),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.dp(10), vertical: r.dp(5)),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB3261E),
                      borderRadius: BorderRadius.circular(20),
                    ),
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
    final r = R.of(context);

    final List<_ShopTheLookOutfit> outfits = _shopTheLookOutfitsToDisplay;
    final int maxProducts = outfits
        .map((o) => o.products.length)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double available = constraints.maxHeight;
          final double usable = available.clamp(0.0, available);

          double heroHeight = usable * 0.55;
          heroHeight = heroHeight < 160.0 ? 160.0 : heroHeight;
          heroHeight = heroHeight > usable ? usable : heroHeight;

          final double remainingForRows = (usable - heroHeight).clamp(0.0, usable);
          double productRowHeight =
              maxProducts > 0 ? remainingForRows / maxProducts : 0.0;
          // Must stay >= the row's own content height (the r.dp(88) product
          // image plus padding) or the row overflows on screens where
          // widthScale pushes r.dp(88) past an unscaled minimum.
          final double minRowHeight = r.dp(108);
          if (maxProducts > 0 && productRowHeight < minRowHeight) {
            productRowHeight = minRowHeight;
          }

          final double cardHeight =
              heroHeight + (productRowHeight * maxProducts);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SizedBox(
                height: cardHeight,
                child: _ShopTheLookAutoSlideCard(
                  outfits: outfits,
                  heroHeight: heroHeight,
                  productRowHeight: productRowHeight,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _shopByOccasionsSection() {
  final r = R.of(context);
  final double cardWidth = MediaQuery.of(context).size.width * 0.44;
  final double cardHeight = (cardWidth * 1.3).clamp(220.0, 380.0);
  final double gap = r.dp(10);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(28), r.dp(16), 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SHOP YOUR AESTHETICS',
              style: TextStyle(
                fontFamily: _fHead,
                fontSize: r.sp(22),
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: r.dp(16)),
      Builder(builder: (context) {
        final tiles = _occasionTilesToDisplay;
        return SizedBox(
          height: cardHeight,
          child: _AutoScrollHorizontalList(
            itemCount: tiles.length,
            itemExtent: cardWidth + gap,
            padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(right: i == tiles.length - 1 ? 0 : gap),
              child: _occasionCard(tiles[i], cardWidth, cardHeight, r),
            ),
          ),
        );
      }),
      SizedBox(height: r.dp(20)),
    ],
  );
}

  Widget _occasionCard(_OccasionTile tile, double width, double height, R r) {
    final bool hasLabel = tile.label != null && tile.label!.trim().isNotEmpty;
    return GestureDetector(
      onTap: () => _openCollectionByHandle(
        tile.handle,
      ),
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
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFFE0E0E0)),
                    errorWidget: (_, __, ___) =>
                        Container(color: const Color(0xFFE0E0E0)),
                  )
                : Container(color: const Color(0xFFE0E0E0)),
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
            if (hasLabel)
              Positioned(
                left: r.dp(12),
                right: r.dp(12),
                bottom: r.dp(12),
                child: Text(
                  tile.label!.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    color: Colors.white,
                    fontSize: r.sp(16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _instagramList() {
  final r = R.of(context);
  final posts = _instagramPostsToDisplay;
  final double cardSize =
      (MediaQuery.of(context).size.width * 0.6).clamp(120.0, 168.0);
  final double gap = r.dp(10);

  return SizedBox(
    height: cardSize,
    child: _AutoScrollHorizontalList(
      itemCount: posts.length,
      itemExtent: cardSize + gap,
      padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
      itemBuilder: (_, i) => Padding(
        padding: EdgeInsets.only(right: i == posts.length - 1 ? 0 : gap),
        child: _instagramBlock(posts[i], cardSize, r),
      ),
    ),
  );
}

Widget _instagramBlock(_InstagramPost post, double size, R r) {
  return GestureDetector(
    onTap: () => _openInstagramPost(post.postUrl),
    child: ClipRRect(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            post.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: post.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFFE0E0E0)),
                    errorWidget: (_, __, ___) =>
                        Container(color: const Color(0xFFE0E0E0)),
                  )
                : Container(color: const Color(0xFFE0E0E0)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.55),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              left: r.dp(8),
              right: r.dp(8),
              bottom: r.dp(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined,
                      color: Colors.white, size: r.dp(12)),
                  SizedBox(width: r.dp(4)),
                  Expanded(
                    child: Text(
                      post.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: _fBody,
                        color: Colors.white,
                        fontSize: r.sp(10.5),
                        shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 4),
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
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent:
                    r.isDesktop ? 260 : (r.isTablet ? 240 : 200),
                crossAxisSpacing: r.dp(12),
                mainAxisSpacing: r.dp(16),
                childAspectRatio: 0.62,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: r.isDesktop ? 10 : (r.isTablet ? 6 : 4),
              itemBuilder: (_, __) => _ShimmerBox(height: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    final r = R.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: r.dp(24), horizontal: r.dp(16)),
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
  final String? imageUrl;
  final String label;
  final String buttonLabel;
  final double height;
  final VoidCallback onTap;
  const _PromoBlockCard({
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
                  : Container(color: const Color(0xFF555555)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: r.dp(18),
                bottom: r.dp(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        color: Colors.white,
                        fontSize: r.sp(32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: r.dp(10)),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.dp(18), vertical: r.dp(11)),
                      color: Colors.black,
                      child: Text(
                        widget.buttonLabel.toUpperCase(),
                        style: TextStyle(
                          fontFamily: AppFonts.bold,
                          color: Colors.white,
                          fontSize: r.sp(12),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
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
  }
}

enum _CollectionTab { newArrivals, bestsellers, sale }

class _ShopifyProductItem {
  final String id;
  final String title;
  final String price;
  final String? compareAtPrice;
  final String? discountLabel;
  final String? imageUrl;
  const _ShopifyProductItem({
    required this.id,
    required this.title,
    required this.price,
    this.compareAtPrice,
    this.discountLabel,
    this.imageUrl,
  });
}

class _ProductsPage {
  final List<_ShopifyProductItem> items;
  final String? endCursor;
  final bool hasNextPage;
  const _ProductsPage({
    required this.items,
    required this.endCursor,
    required this.hasNextPage,
  });
}

class _ShopTheLookOutfit {
  final String? imageUrl;
  final List<_ShopTheLookProduct> products;
  const _ShopTheLookOutfit({
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

  void _startAutoSlide() {
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      _index = (_index + 1) % widget.outfits.length;
      _controller.animateToPage(
        _index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
      if (mounted) setState(() {});
    });
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
                final success =
                    await CartService.instance.addLine(variantId: variantId);
                if (!context.mounted) return;
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
      return Container(color: AppColors.fieldFill);
    }

    return PageView.builder(
      controller: _controller,
      itemCount: widget.outfits.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (_, i) {
        final outfit = widget.outfits[i];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
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
                      color: AppColors.card,
                      child: outfit.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: outfit.imageUrl!,
                              fit: BoxFit.contain,
                              placeholder: (_, __) =>
                                  Container(color: AppColors.fieldFill),
                              errorWidget: (_, __, ___) =>
                                  Container(color: AppColors.fieldFill),
                            )
                          : Container(color: AppColors.fieldFill),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.20),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3],
                        ),
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
                          top: BorderSide(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: r.dp(12)),
                      child: Row(
                        children: [
                          Container(
                            width: r.dp(88),
                            height: r.dp(88),
                            color: AppColors.fieldFill,
                            child: item.imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: item.imageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => const SizedBox(),
                                    errorWidget: (_, __, ___) =>
                                        const SizedBox(),
                                  )
                                : const SizedBox(),
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
                                    color: AppColors.primary,
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
                                    color: AppColors.primary,
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
                              color: AppColors.primary.withOpacity(0.08),
                              child: Icon(
                                Icons.add_rounded,
                                size: r.dp(15),
                                color: AppColors.primary,
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
          final base = AppColors.fieldFill;
          final highlight = Color.lerp(AppColors.fieldFill, AppColors.card, 0.6)!;
          return ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment(-1 - t * 2, 0),
              end: Alignment(1 - t * 2, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(rect),
            child: Container(
              height: widget.height,
              width: widget.width,
              color: base,
            ),
          );
        },
      ),
    );
  }
}

class _OccasionTile {
  final String? imageUrl;
  final String handle;
  final String? label;
  const _OccasionTile({
    this.imageUrl,
    required this.handle,
    this.label,
  });
}

class _ShopTheLookProduct {
  final String title;
  final String price;
  final String? imageUrl;
  final ShopifyProduct? product;
  const _ShopTheLookProduct({
    required this.title,
    required this.price,
    this.imageUrl,
    this.product,
  });
}

class _InstagramPost {
  final String? imageUrl;
  final String postUrl;
  final String username;
  const _InstagramPost({
    this.imageUrl,
    required this.postUrl,
    required this.username,
  });
}

class _PromoBlockData {
  final String? imageUrl;
  final String label;
  final String buttonLabel;
  final String collectionHandle;
  const _PromoBlockData({
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
            .animateTo(max,
                duration: widget.animationDuration, curve: Curves.easeInOut)
            .then((_) {
          if (!mounted) return;
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && _controller.hasClients) {
              _controller.animateTo(0,
                  duration: widget.animationDuration,
                  curve: Curves.easeInOut);
            }
          });
        });
      } else {
        _controller.animateTo(next,
            duration: widget.animationDuration, curve: Curves.easeInOut);
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