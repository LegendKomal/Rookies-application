import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/screens/products/products.dart';
import 'package:rookies_jeans/screens/search/search.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';

typedef R = Responsive;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primary      = AppColors.primary;
  static const Color bgColor      = AppColors.bg;
  static const Color secondaryTxt = AppColors.secondaryText;
  static const String _fHead   = AppFonts.heading;
  static const String _fBody   = AppFonts.body;
  static const String _fBold   = AppFonts.bold;
  static const String _fNumber = AppFonts.number;

  // Height reserved at the bottom of scroll content so the last section
  // isn't hidden behind the floating glass pill nav bar.
  static const double _kBottomNavHeight = 60.0;
  static const double _kBottomNavClearance = 84.0;
  static const double _kSectionGap = 24.0;

  // How many pixels of scroll it takes for the floating top bar to go
  // from fully transparent (over the hero image) to fully solid.
  static const double _kTopBarFadeDistance = 220.0;

  // Placeholder hero copy — swap for real CMS/Shopify metaobject content
  // whenever it's available. The headline runs continuously as a ticker.
  static const String _heroMarqueeText = 'READY FOR MORE';
  static const String _heroSubtitle =
      'Renaisse redefines streetwear with bold silhouettes and clean essentials.';

  bool _isLoading = true;
  List<ShopifyCollection> _categories = [];

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollProgress = ValueNotifier<double>(0.0);

  _CollectionTab _selectedCollectionTab = _CollectionTab.newArrivals;

  // Per-tab pagination state for "Explore collection". Each tab keeps its
  // own loaded-items list, next-page cursor, and hasNextPage flag so
  // switching tabs doesn't lose progress and "Show More" always appends
  // exactly one page (6 products) to the current tab.
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

  final List<_ShopTheLookOutfit> _shopTheLookOutfits = const [
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

  // ---------------------------------------------------------------------
  // Explore collection — product fetching (6-at-a-time pagination)
  // ---------------------------------------------------------------------
  //
  // `_loadMoreCollectionProducts` is what "Show More" calls. It always
  // asks for exactly one page (6 products) for whichever tab is active and
  // appends them to that tab's already-loaded list.
  //
  // `_fetchProductsPage` is the SINGLE INTEGRATION POINT to wire in real
  // data — see the TODO inside it. Until that's connected it paginates
  // through local sample data so the loading state / 6-at-a-time / "no
  // more results" behaviour all work correctly end to end.

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
    // -----------------------------------------------------------------
    // TODO: replace this whole body with your real Shopify Storefront
    // product query, e.g. something like:
    //
    //   final result = await ShopifyStorefrontService.instance.getProducts(
    //     collectionHandle: _collectionHandleForTab(tab),
    //     first: 6,
    //     after: after,
    //   );
    //   return _ProductsPage(
    //     items: result.products.map(_mapShopifyProductToItem).toList(),
    //     endCursor: result.pageInfo.endCursor,
    //     hasNextPage: result.pageInfo.hasNextPage,
    //   );
    //
    // `after` is the opaque cursor from the previous page (null for the
    // first page) — pass it straight through to your Storefront query.
    // -----------------------------------------------------------------
    await Future.delayed(const Duration(milliseconds: 350)); // simulated latency
    final List<_ShopifyProductItem> all = _placeholderProductsFor(tab);
    final int start = after == null ? 0 : int.parse(after);
    final int end = (start + 6).clamp(0, all.length);
    final bool hasNext = end < all.length;
    return _ProductsPage(
      items: all.sublist(start.clamp(0, all.length), end),
      endCursor: hasNext ? '$end' : null,
      hasNextPage: hasNext,
    );
  }

  String _collectionHandleForTab(_CollectionTab tab) {
    switch (tab) {
      case _CollectionTab.newArrivals:
        return 'new-arrivals';
      case _CollectionTab.bestsellers:
        return 'bestsellers';
      case _CollectionTab.sale:
        return 'sale';
    }
  }

  // Sample data standing in for the real Shopify fetch above — enough
  // items per tab (10) to demonstrate two "Show More" pages (6 + 4).
  List<_ShopifyProductItem> _placeholderProductsFor(_CollectionTab tab) {
    const assets = [
      'assets/collection_cargo_olive.jpg',
      'assets/collection_cargo_black.jpg',
      'assets/collection_jeans_medblue.jpg',
      'assets/collection_jeans_lightblue.jpg',
      'assets/collection_shirt_black.jpg',
      'assets/collection_cargo_white.jpg',
    ];
    const titlesByTab = {
      _CollectionTab.newArrivals: [
        'Olive Comfort Straight Fit Stretch Cargo Pants',
        'Black Balloon Fit Cargo Pants',
        'Med Blue Mid Rise Cropped Length Loose Boot Leg Stretch Jeans',
        'Light Blue Mid Rise Loose Boot Leg Stretch Jeans',
        'Black 100% Cotton Oversized Solid Shirt',
        'White Balloon Fit Stretch Cargo Pants',
      ],
      _CollectionTab.bestsellers: [
        'Black 100% Cotton Oversized Solid Shirt',
        'Olive Comfort Straight Fit Stretch Cargo Pants',
        'Med Blue Mid Rise Cropped Length Loose Boot Leg Stretch Jeans',
      ],
      _CollectionTab.sale: [
        'White Balloon Fit Stretch Cargo Pants',
        'Light Blue Mid Rise Loose Boot Leg Stretch Jeans',
        'Med Blue Mid Rise Cropped Length Loose Boot Leg Stretch Jeans',
      ],
    };
    final titles = titlesByTab[tab]!;
    return List.generate(10, (i) {
      final String title = titles[i % titles.length];
      final bool onSale = i.isEven;
      final int base = 1799 + (i * 100);
      return _ShopifyProductItem(
        id: '${tab.name}-$i',
        title: title,
        price: '₹ ${base + (onSale ? 0 : 200)}',
        compareAtPrice: onSale ? '₹ ${base + 200}' : null,
        discountLabel: onSale ? '${5 + (i % 4) * 3}% OFF' : null,
        imageUrl: null, // real fetch will populate this from Shopify
        imageAssetFallback: assets[i % assets.length],
      );
    });
  }



  final List<_OccasionTile> _occasionTiles = const [
    _OccasionTile(
      imageAsset: 'assets/jeans_jann.jpg',
      line1: 'JEANS',
      line2: 'JANN',
      handle: 'jeans-jann',
    ),
    _OccasionTile(
      imageAsset: 'assets/jeans_jesse.jpg',
      line1: 'JEANS',
      line2: 'JESSE',
      handle: 'jeans-jesse',
    ),
    _OccasionTile(
      imageAsset: 'assets/jeans_jamie.jpg',
      line1: 'JEANS',
      line2: 'JAMIE',
      handle: 'jeans-jamie',
    ),
    _OccasionTile(
      imageAsset: 'assets/jeans_jude.jpg',
      line1: 'JEANS',
      line2: 'JUDE',
      handle: 'jeans-jude',
    ),
    _OccasionTile(
      imageAsset: 'assets/jeans_jax.jpg',
      line1: 'JEANS',
      line2: 'JAX',
      handle: 'jeans-jax',
    ),
    _OccasionTile(
      imageAsset: 'assets/jeans_joel.jpg',
      line1: 'JEANS',
      line2: 'JOEL',
      handle: 'jeans-joel',
    ),
  ];

  final List<_InstagramPost> _instagramPosts = const [
    _InstagramPost(
      imageAsset: 'assets/instagram_1.jpg',
      postUrl: 'https://www.instagram.com/p/REPLACE_ME_1/',
      username: 'softlayers',
    ),
    _InstagramPost(
      imageAsset: 'assets/instagram_2.jpg',
      postUrl: 'https://www.instagram.com/p/REPLACE_ME_2/',
      username: 'rookiesjeans',
    ),
    _InstagramPost(
      imageAsset: 'assets/instagram_3.jpg',
      postUrl: 'https://www.instagram.com/p/REPLACE_ME_3/',
      username: 'rookiesjeans',
    ),
    _InstagramPost(
      imageAsset: 'assets/instagram_4.jpg',
      postUrl: 'https://www.instagram.com/p/REPLACE_ME_4/',
      username: 'rookiesjeans',
    ),
    _InstagramPost(
      imageAsset: 'assets/instagram_5.jpg',
      postUrl: 'https://www.instagram.com/p/REPLACE_ME_5/',
      username: 'rookiesjeans',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _loadMoreCollectionProducts(_selectedCollectionTab);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final progress =
        (_scrollController.offset / _kTopBarFadeDistance).clamp(0.0, 1.0);
    if (_scrollProgress.value != progress) {
      _scrollProgress.value = progress;
    }
  }

  Future<void> _fetchAll({bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoading = true);
    if (forceRefresh) {
      ShopifyStorefrontService.instance.clearCache();
    }
    final categories =
        await ShopifyStorefrontService.instance.getLatestDropCollections();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoading  = false;
    });
  }

  void _openCollection(ShopifyCollection collection) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductsPage(collection: collection)),
    );
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
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: this Scaffold is transparent on purpose.
    // HomeScreen is expected to be hosted inside a parent Scaffold that owns
    // `bottomNavigationBar: RookiesBottomNavBar(...)` and sets
    // `extendBody: true`. The Container(color: bgColor) below still gives
    // this screen a correct light background if it's ever previewed on its
    // own.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? _shimmer()
            : Container(
                color: bgColor,
                child: Stack(
                  children: [
                    RefreshIndicator(
                      color: primary,
                      onRefresh: _fetchAll,
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: _heroSection()),
                          SliverToBoxAdapter(
                            child: _PromoBlockCard(
                              assetPath: 'assets/denim.png',
                              label: 'Denim',
                              buttonLabel: 'Shop Denim',
                              height: _promoBlockHeight(context),
                              onTap: () => _openCollectionByHandle('denim',
                                  title: 'Denim', label: 'DENIM'),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _PromoBlockCard(
                              assetPath: 'assets/cargo.png',
                              label: 'Cargos',
                              buttonLabel: 'Shop Cargos',
                              height: _promoBlockHeight(context),
                              onTap: () => _openCollectionByHandle('cargo',
                                  title: 'Cargo', label: 'CARGO'),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _sliverHeadAsBox('EXPLORE CATEGORIES'),
                          ),
                          SliverToBoxAdapter(child: _exploreCategoriesCarousel()),
                          SliverToBoxAdapter(
                            child: _PromoBlockCard(
                              assetPath: 'assets/shoes.jpg',
                              label: 'Shoes',
                              buttonLabel: 'Shop Shoes',
                              height: _promoBlockHeight(context),
                              onTap: () => _openCollectionByHandle('shoes',
                                  title: 'Shoes', label: 'SHOES'),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _PromoBlockCard(
                              assetPath: 'assets/accessories.jpg',
                              label: 'Accessories',
                              buttonLabel: 'Shop Accessories',
                              height: _promoBlockHeight(context),
                              onTap: () => _openCollectionByHandle('accessories',
                                  title: 'Accessories', label: 'ACCESSORIES'),
                            ),
                          ),
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
                    _floatingTopBar(),
                  ],
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Sizing helpers
  // ---------------------------------------------------------------------

  double _fullScreenBannerHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.size.height - mq.padding.top - mq.padding.bottom;
  }

  double _promoBlockHeight(BuildContext context) =>
      (MediaQuery.of(context).size.height * 0.46).clamp(220.0, 420.0);

  // ---------------------------------------------------------------------
  // Floating glass top bar — transparent over the hero, solidifies on
  // scroll. No hamburger, no cart: search · logo · wishlist / account.
  // ---------------------------------------------------------------------

  Widget _floatingTopBar() {
    final r = R.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<double>(
        valueListenable: _scrollProgress,
        builder: (context, progress, _) {
          final panelColor = Color.lerp(Colors.transparent, bgColor, progress)!;
          final iconColor = Color.lerp(Colors.white, primary, progress)!;
          return ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 8 * progress,
                sigmaY: 8 * progress,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: panelColor.withOpacity(progress),
                  boxShadow: progress > 0.4
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06 * progress),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : const [],
                ),
                child: SizedBox(
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
                              color: iconColor,
                              onPressed: _openSearch,
                            ),
                          ),
                        ),
                        Image.asset(
                          'assets/logo2.png',
                          height: r.dp(14),
                          fit: BoxFit.contain,
                          color: iconColor,
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
                                  color: iconColor,
                                  onPressed: () => context.go('/wishlist'),
                                ),
                                IconButton(
                                  icon: Icon(Icons.person_outline_rounded,
                                      size: r.dp(22)),
                                  color: iconColor,
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Hero — running "READY FOR MORE" ticker + tagline + Shop now
  // ---------------------------------------------------------------------

  Widget _heroSection() {
    final r = R.of(context);
    return SizedBox(
      height: _fullScreenBannerHeight(context),
      width: double.infinity,
      child: Stack(
        children: [
          _heroBannerImage(),
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
                  // Full-bleed running ticker — deliberately ignores the
                  // side padding below so it reads edge-to-edge, like a
                  // marquee, matching the reference site.
                  _HeroMarqueeText(
                    text: _heroMarqueeText,
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
                          _heroSubtitle,
                          style: TextStyle(
                            fontFamily: _fBody,
                            fontSize: r.sp(13),
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(height: r.dp(14)),
                        GestureDetector(
                          onTap: () {}, // TODO: point at the featured collection/handle
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
                                  'Shop now',
                                  style: TextStyle(
                                    fontFamily: _fBold,
                                    color: primary,
                                    fontSize: r.sp(13),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: r.dp(6)),
                                Icon(Icons.arrow_forward_rounded,
                                    size: r.dp(16), color: primary),
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
          Image.asset(
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

  // ---------------------------------------------------------------------
  // Section headers (dark text — content sits on the light page background)
  // ---------------------------------------------------------------------

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

  // ---------------------------------------------------------------------
  // Explore categories — horizontally scrollable cards (swipe, no arrows)
  // ---------------------------------------------------------------------

  // Naive keyword split — ShopifyCollection doesn't carry a "type" field,
  // so we bucket by label until a real topwear/bottomwear tag/metafield is
  // available from Shopify. Anything that doesn't match a bottomwear
  // keyword is treated as topwear.
  static const List<String> _bottomwearKeywords = [
    'pant', 'jean', 'cargo', 'trouser', 'short', 'jogger', 'chino', 'bottom',
  ];

  bool _isBottomwear(String label) {
    final l = label.toLowerCase();
    return _bottomwearKeywords.any((k) => l.contains(k));
  }

  Widget _exploreCategoriesCarousel() {
    final r = R.of(context);
    if (_categories.isEmpty) return _empty();

    final double cardWidth = MediaQuery.of(context).size.width * 0.56;
    final double cardHeight = cardWidth.clamp(190.0, 260.0);

    final List<ShopifyCollection> topwear =
        _categories.where((c) => !_isBottomwear(c.label)).toList();
    final List<ShopifyCollection> bottomwear =
        _categories.where((c) => _isBottomwear(c.label)).toList();

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
      List<ShopifyCollection> items, double cardWidth, double cardHeight, R r) {
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
            onTap: () => _openCollection(cat),
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

  // ---------------------------------------------------------------------
  // Explore collection — pill tabs + 2-col product grid + "Show More"
  // ---------------------------------------------------------------------

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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
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
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: (_isLoadingCollectionProducts && products.isNotEmpty)
                    ? SizedBox(
                        width: r.dp(18),
                        height: r.dp(18),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Show More',
                        style: TextStyle(
                          fontFamily: _fBold,
                          color: Colors.white,
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
          color: selected ? Colors.black : Colors.white,
          border: Border.all(color: Colors.black, width: 1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: _fBold,
            fontSize: r.sp(11),
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black,
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
          maxLines: 2,
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

  // ---------------------------------------------------------------------
  // Shop the look
  // ---------------------------------------------------------------------

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

    final int maxProducts = _shopTheLookOutfits
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
          if (maxProducts > 0 && productRowHeight < 56.0) {
            productRowHeight = 56.0;
          }

          final double cardHeight =
              heroHeight + (productRowHeight * maxProducts);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SizedBox(
                height: cardHeight,
                child: _ShopTheLookAutoSlideCard(
                  outfits: _shopTheLookOutfits,
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

  // ---------------------------------------------------------------------
  // Shop by occasions — horizontally scrollable cards
  // ---------------------------------------------------------------------

  Widget _shopByOccasionsSection() {
    final r = R.of(context);
    final double cardWidth = MediaQuery.of(context).size.width * 0.44;
    final double cardHeight = (cardWidth * 1.3).clamp(220.0, 380.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GLOW MUST-HAVES',
                style: TextStyle(
                  fontFamily: _fBody,
                  fontSize: r.sp(11),
                  color: secondaryTxt,
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: r.dp(6)),
              Text(
                'SHOP BY OCCASIONS',
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
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _occasionTiles.length,
            separatorBuilder: (_, __) => SizedBox(width: r.dp(10)),
            itemBuilder: (_, i) {
              final tile = _occasionTiles[i];
              return _occasionCard(tile, cardWidth, cardHeight, r);
            },
          ),
        ),
        SizedBox(height: r.dp(20)),
      ],
    );
  }

  Widget _occasionCard(_OccasionTile tile, double width, double height, R r) {
    return GestureDetector(
      onTap: () => _openCollectionByHandle(
        tile.handle,
        title: '${tile.line1} ${tile.line2}',
        label: '${tile.line1} ${tile.line2}',
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              tile.imageAsset,
              fit: BoxFit.cover,
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
            Positioned(
              left: 0,
              right: 0,
              bottom: r.dp(16),
              child: Column(
                children: [
                  Text(
                    tile.line1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _fBold,
                      color: Colors.white,
                      fontSize: r.sp(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    tile.line2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _fBold,
                      color: Colors.white,
                      fontSize: r.sp(15),
                      fontWeight: FontWeight.w700,
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

  // ---------------------------------------------------------------------
  // Follow us — single-column Instagram posts, ROOKIES wordmark + @handle
  // ---------------------------------------------------------------------

  Widget _instagramList() {
    final double screenWidth = MediaQuery.of(context).size.width;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _instagramPosts.length; i++) ...[
          if (i > 0) const SizedBox(height: 2),
          _instagramBlock(_instagramPosts[i], screenWidth),
        ],
      ],
    );
  }

  Widget _instagramBlock(_InstagramPost post, double width) {
    final r = R.of(context);
    return GestureDetector(
      onTap: () => _openInstagramPost(post.postUrl),
      child: SizedBox(
        width: width,
        height: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              post.imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: const Color(0xFFE0E0E0)),
            ),
            Positioned(
              left: r.dp(12),
              top: r.dp(12),
              child: Text(
                'ROOKIES',
                style: TextStyle(
                  fontFamily: _fHead,
                  color: Colors.white,
                  fontSize: r.sp(14),
                  fontWeight: FontWeight.w600,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
            ),
            Positioned(
              left: r.dp(12),
              bottom: r.dp(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined,
                      color: Colors.white, size: r.dp(16)),
                  SizedBox(width: r.dp(6)),
                  Text(
                    post.username,
                    style: TextStyle(
                      fontFamily: _fBody,
                      color: Colors.white,
                      fontSize: r.sp(12),
                      shadows: const [
                        Shadow(color: Colors.black45, blurRadius: 4)
                      ],
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

  // ---------------------------------------------------------------------
  // Loading skeleton
  // ---------------------------------------------------------------------

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
              children: List.generate(4, (_) => _ShimmerBox(height: double.infinity)),
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

// ===========================================================================
// Hero running ticker — full-bleed, continuously auto-scrolling headline
// ===========================================================================

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

// ===========================================================================
// Promo block card — sharp corners, "SHOP X" button, tap-scale feedback
// ===========================================================================

class _PromoBlockCard extends StatefulWidget {
  final String assetPath;
  final String label;
  final String buttonLabel;
  final double height;
  final VoidCallback onTap;
  const _PromoBlockCard({
    required this.assetPath,
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
              Image.asset(
                widget.assetPath,
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

// ===========================================================================
// Explore-collection product models
// ===========================================================================

enum _CollectionTab { newArrivals, bestsellers, sale }

/// A single product card's worth of data. `imageUrl` is what a real
/// Shopify fetch will populate; `imageAssetFallback` is only used by the
/// local placeholder data in `_placeholderProductsFor`.
class _ShopifyProductItem {
  final String id;
  final String title;
  final String price;
  final String? compareAtPrice;
  final String? discountLabel;
  final String? imageUrl;
  final String imageAssetFallback;
  const _ShopifyProductItem({
    required this.id,
    required this.title,
    required this.price,
    this.compareAtPrice,
    this.discountLabel,
    this.imageUrl,
    this.imageAssetFallback = 'assets/collection_cargo_olive.jpg',
  });
}

/// One page of paginated product results — mirrors the shape a Shopify
/// Storefront GraphQL connection (edges + pageInfo) naturally produces.
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

// ===========================================================================
// Shop the look card
// ===========================================================================

class _ShopTheLookOutfit {
  final String imageAsset;
  final List<_ShopTheLookProduct> products;
  const _ShopTheLookOutfit({
    required this.imageAsset,
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

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);

    if (widget.outfits.isEmpty) {
      return Container(color: const Color(0xFF555555));
    }

    return PageView.builder(
      controller: _controller,
      itemCount: widget.outfits.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (_, i) {
        final outfit = widget.outfits[i];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
                    Image.asset(
                      outfit.imageAsset,
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
                            Colors.black.withOpacity(0.20),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3],
                        ),
                      ),
                    ),
                    Positioned(
                      top: r.dp(12),
                      left: r.dp(12),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.dp(10),
                          vertical: r.dp(5),
                        ),
                        color: Colors.white.withOpacity(0.92),
                        child: Text(
                          'LOOK ${i + 1}/${widget.outfits.length}',
                          style: TextStyle(
                            fontFamily: AppFonts.bold,
                            fontSize: r.sp(9.5),
                            letterSpacing: 0.6,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...List.generate(outfit.products.length, (j) {
                final item = outfit.products[j];
                return SizedBox(
                  height: widget.productRowHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFFEDEDED),
                          width: 1,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: r.dp(12)),
                    child: Row(
                      children: [
                        Container(
                          width: r.dp(42),
                          height: r.dp(42),
                          color: const Color(0xFFECECEC),
                          child: Image.asset(
                            item.imageAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(),
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
                        Container(
                          width: r.dp(26),
                          height: r.dp(26),
                          color: AppColors.primary.withOpacity(0.08),
                          child: Icon(
                            Icons.add_rounded,
                            size: r.dp(15),
                            color: AppColors.primary,
                          ),
                        ),
                      ],
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

// ===========================================================================
// Animated shimmer skeleton block
// ===========================================================================

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

// ===========================================================================
// Data models
// ===========================================================================

class _OccasionTile {
  final String imageAsset;
  final String line1;
  final String line2;
  final String handle;
  const _OccasionTile({
    required this.imageAsset,
    required this.line1,
    required this.line2,
    required this.handle,
  });
}

class _ShopTheLookProduct {
  final String title;
  final String price;
  final String imageAsset;
  const _ShopTheLookProduct({
    required this.title,
    required this.price,
    required this.imageAsset,
  });
}

class _InstagramPost {
  final String imageAsset;
  final String postUrl;
  final String username;
  const _InstagramPost({
    required this.imageAsset,
    required this.postUrl,
    required this.username,
  });
}