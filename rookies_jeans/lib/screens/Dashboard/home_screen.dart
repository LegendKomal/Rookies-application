import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/screens/products/products.dart';
import 'package:rookies_jeans/screens/search/search.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';
import 'package:rookies_jeans/services/cart_service.dart';

typedef R = Responsive;

// Shared by _shopTheLookAsBox (height math) and _ShopTheLookAutoSlideCard
// (the actual painted border) so the two can never get out of sync.
const double _kCardBorderWidth = 0.75;

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

  bool _isLoading = true;
  final ScrollController _scrollCtrl = ScrollController();
  final List<_SectionAnchor> _sectionAnchors = [];
  bool _isSnapping = false;
  BuildContext? _scrollableContext;

  List<ShopifyCollection> _categories = [];

  // Each "look" now carries its own outfit image AND the products shown
  // with it, so the whole card (image + product rows) slides as one unit.
  final List<_ShopTheLookOutfit> _shopTheLookOutfits = const [
    _ShopTheLookOutfit(
      imageAsset: 'assets/shop_the_look_outfit_1.jpg',
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

  final List<_PromoCollectionTile> _shopByCollectionTiles = const [
    _PromoCollectionTile(
      title: 'OVERSIZED TEES',
      handle: 'ss26-tshirts-oversize-fit-half-sleeve',
      imageAsset: 'assets/oversized_tees.jpg',
    ),
    _PromoCollectionTile(
      title: 'BALLOON FIT PANTS',
      handle: 'baloon-fit-pants',
      imageAsset: 'assets/balloon_fit_pants.jpg',
    ),
    _PromoCollectionTile(
      title: 'OVERSIZED SHIRTS',
      handle: 'oversized-shirts',
      imageAsset: 'assets/oversized_shirts.jpg',
    ),
    _PromoCollectionTile(
      title: 'LINENS',
      handle: 'ss26-linens',
      imageAsset: 'assets/linens.jpg',
    ),
    _PromoCollectionTile(
      title: 'LOOSE FIT JEANS',
      handle: 'ss26-loose-fit-jeans',
      imageAsset: 'assets/loose_fit_jeans.jpg',
    ),
    _PromoCollectionTile(
      title: 'BOOTCUT FIT JEANS',
      handle: 'ss26-bootcutjeans',
      imageAsset: 'assets/bootcut_fit_jeans.jpg',
    ),
  ];

  final List<_InstagramPost> _instagramPosts = const [
    _InstagramPost(
      imageAsset: 'assets/instagram_1.jpg',
      postUrl: 'https://www.instagram.com/p/REPLACE_ME_1/',
    ),
    _InstagramPost(
      imageAsset: 'assets/instagram_2.jpg',
      postUrl: 'https://www.instagram.com/p/REPLACE_ME_2/',
    ),
    _InstagramPost(
      imageAsset: 'assets/instagram_3.jpg',
      postUrl: 'https://www.instagram.com/p/REPLACE_ME_3/',
    ),
    _InstagramPost(
      imageAsset: 'assets/instagram_4.jpg',
      postUrl: 'https://www.instagram.com/p/REPLACE_ME_4/',
    ),
    _InstagramPost(
      imageAsset: 'assets/instagram_5.jpg',
      postUrl: 'https://www.instagram.com/p/REPLACE_ME_5/',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchAll();
    CartService.instance.initialize();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _registerAnchor(_SectionAnchor anchor) {
    if (!_sectionAnchors.any((a) => a.key == anchor.key)) {
      _sectionAnchors.add(anchor);
    }
  }

  List<double> _collectSectionOffsets() {
    final offsets = <double>[];
    for (final anchor in _sectionAnchors) {
      final ctx = anchor.key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final scrollBox =
          _scrollableContext?.findRenderObject() as RenderBox?;
      if (scrollBox == null) continue;
      final position = box.localToGlobal(Offset.zero, ancestor: scrollBox);
      offsets.add(_scrollCtrl.offset + position.dy);
    }
    offsets.sort();
    return offsets;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification && !_isSnapping) {
      _snapToNearestSection();
    }
    return false;
  }

  Future<void> _snapToNearestSection() async {
    final offsets   = _collectSectionOffsets();
    if (offsets.isEmpty) return;
    final current   = _scrollCtrl.offset;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;
    double nearest   = offsets.first;
    double bestDelta = (offsets.first - current).abs();
    for (final o in offsets) {
      final delta = (o - current).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        nearest   = o;
      }
    }
    final target = nearest.clamp(0.0, maxScroll);
    if ((target - current).abs() < 1.0) return;
    _isSnapping = true;
    try {
      await _scrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isSnapping = false;
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

  Future<void> _openInstagramPost(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _logout() async {
    await ShopifyAuthService.instance.logout();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    _sectionAnchors.clear();
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? _shimmer()
            : Builder(
                builder: (scrollableContext) {
                  _scrollableContext = scrollableContext;
                  return NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: RefreshIndicator(
                      color: primary,
                      onRefresh: _fetchAll,
                      child: CustomScrollView(
                        controller: _scrollCtrl,
                        physics: const ClampingScrollPhysics(),
                        slivers: [
                          _snapSection(
                            id: 'banner',
                            child: _sliverBannerWithOverlayBar(),
                          ),
                          _snapSection(
                            id: 'denim_cargo',
                            child: _sliverDenimCargoBlocks(),
                          ),
                          _snapSection(
                            id: 'categories',
                            child: _exploreCategoriesSection(),
                          ),
                          _snapSection(
                            id: 'bestseller_sales',
                            child: _sliverBestsellerSalesBlocks(),
                          ),
                          _snapSection(
                            id: 'shop_the_look',
                            child: _shopTheLookSection(),
                          ),
                          _snapSection(
                            id: 'editorial',
                            child: _editorialSection(),
                          ),
                          _snapSection(
                            id: 'shop_by_collection',
                            child: _shopByCollectionSection(),
                          ),
                          _snapSection(
                            id: 'instagram',
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _sliverCenteredHeadAsBox('FOLLOW US'),
                                _instagramSectionAsBox(),
                              ],
                            ),
                          ),
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 40)),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _snapSection({required String id, required Widget child}) {
    final key = GlobalKey(debugLabel: id);
    _registerAnchor(_SectionAnchor(id: id, key: key));
    return SliverToBoxAdapter(
      child: KeyedSubtree(key: key, child: child),
    );
  }

  double _fullScreenBannerHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.size.height - mq.padding.top - mq.padding.bottom;
  }

  // ---------------------------------------------------------------------
  // 1. HERO BANNER (image, replaces the old video banner)
  // ---------------------------------------------------------------------

  Widget _sliverBannerWithOverlayBar() {
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
            height: r.dp(80),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.40),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: r.dp(8),
                vertical: r.dp(6),
              ),
              child: SizedBox(
                height: r.dp(56),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: Icon(Icons.search, size: r.dp(22)),
                          color: Colors.white,
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, animation, __) =>
                                    const SearchPage(),
                                transitionsBuilder:
                                    (_, animation, __, child) =>
                                        FadeTransition(
                                          opacity: CurvedAnimation(
                                            parent: animation,
                                            curve: Curves.easeOut,
                                          ),
                                          child: child,
                                        ),
                                transitionDuration:
                                    const Duration(milliseconds: 200),
                              ),
                            );
                          },
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
                              icon: Icon(
                                Icons.favorite_border_rounded,
                                size: r.dp(22),
                              ),
                              color: Colors.white,
                              onPressed: () => context.go('/wishlist'),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.person_outline_rounded,
                                size: r.dp(22),
                              ),
                              color: Colors.white,
                              tooltip: 'Logout',
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
        ],
      ),
    );
  }

  Widget _heroBannerImage() => Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/hero_banner.jpg',
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
                      Colors.black.withOpacity(0.55),
                      Colors.black.withOpacity(0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.28, 0.55],
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
      padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(18), r.dp(16), r.dp(10)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: _fHead,
            fontSize: r.sp(35),
            fontWeight: FontWeight.w500,
            color: primary,
          ),
        ),
      ),
    );
  }

  Widget _sliverCenteredHeadAsBox(String title) {
    final r = R.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(50), r.dp(16), r.dp(16)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: _fHead,
            fontSize: r.sp(40),
            fontWeight: FontWeight.w500,
            color: primary,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 2. DENIM & CARGO (same visual pattern as Bestseller / Sale)
  // ---------------------------------------------------------------------

  Widget _sliverDenimCargoBlocks() {
    final r = R.of(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double blockHeight =
        (MediaQuery.of(context).size.height * 0.46).clamp(220.0, 420.0);
    return Column(
      children: [
        _fullWidthImageBlock(
          assetPath: 'assets/denim.jpg',
          label: 'Denim',
          width: screenWidth,
          height: blockHeight,
          onTap: () => _openCollectionByHandle('denim',
              title: 'Denim', label: 'DENIM'),
          r: r,
        ),
        _fullWidthImageBlock(
          assetPath: 'assets/cargo.jpg',
          label: 'Cargo',
          width: screenWidth,
          height: blockHeight,
          onTap: () => _openCollectionByHandle('cargo',
              title: 'Cargo', label: 'CARGO'),
          r: r,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 3. EXPLORE CATEGORIES (heading + single-image auto-sliding banner)
  // ---------------------------------------------------------------------

  Widget _exploreCategoriesSection() {
    final double bannerHeight =
        (MediaQuery.of(context).size.height * 0.9).clamp(220.0, 550.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sliverHeadAsBox('EXPLORE CATEGORIES'),
        _categories.isEmpty
            ? _empty()
            : _AutoSlideCollectionBanner(
                height: bannerHeight,
                items: _categories
                    .map((cat) => _SlideItem(
                          image: cat.imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: cat.imageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                      color: const Color(0xFF555555)),
                                  errorWidget: (_, __, ___) => Container(
                                      color: const Color(0xFF555555)),
                                )
                              : Container(color: const Color(0xFF555555)),
                          label: cat.label,
                          onTap: () => _openCollection(cat),
                        ))
                    .toList(),
              ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 4. BESTSELLER & SALE (unchanged)
  // ---------------------------------------------------------------------

  Widget _sliverBestsellerSalesBlocks() {
    final r = R.of(context);
    final double screenWidth  = MediaQuery.of(context).size.width;
    final double blockHeight  =
        (MediaQuery.of(context).size.height * 0.46).clamp(220.0, 420.0);
    return Column(
      children: [
        _fullWidthImageBlock(
          assetPath: 'assets/bestseller.jpg',
          label: 'Bestsellers',
          width: screenWidth,
          height: blockHeight,
          onTap: () {},
          r: r,
        ),
        _fullWidthImageBlock(
          assetPath: 'assets/sales.jpg',
          label: 'Sale',
          width: screenWidth,
          height: blockHeight,
          onTap: () {},
          r: r,
        ),
      ],
    );
  }

  Widget _fullWidthImageBlock({
    required String assetPath,
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
            Image.asset(
              assetPath,
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
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.45),
                  ],
                ),
              ),
            ),
            Positioned(
              left: r.dp(18),
              bottom: r.dp(11),
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: _fHead,
                  color: Colors.white,
                  fontSize: r.sp(35),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 5. SHOP THE LOOK (whole card — image + product rows — auto-slides)
  // ---------------------------------------------------------------------

  Widget _shopTheLookSection() {
    // The header takes its natural size; the card claims whatever height is
    // left via Expanded. Because Expanded can never ask for more than its
    // parent has, this can't overflow regardless of screen size or font scale.
    return SizedBox(
      height: _fullScreenBannerHeight(context),
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

    // Different looks can carry different numbers of products, so we size
    // every card to fit the one with the most rows; shorter cards get a
    // little extra breathing room at the bottom.
    final int maxProducts = _shopTheLookOutfits
        .map((o) => o.products.length)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // constraints.maxHeight is exactly what Expanded handed us, so
          // everything below is derived from real available space instead
          // of fixed numbers — this is what makes it responsive.
          final double available = constraints.maxHeight;

          // _ShopTheLookAutoSlideCardState wraps each page in a
          // Container(border: Border.all(width: _kCardBorderWidth)).
          // Flutter auto-insets a Container's child by the border width on
          // every side, which is exactly the 1.5px this used to overflow
          // by. Reserving it here up front is the actual fix.
          const double borderInsets = _kCardBorderWidth * 2;
          final double usable =
              (available - borderInsets).clamp(0.0, available);

          // Fill the ENTIRE available height, the same way the hero banner
          // fills the full screen — no upper cap, so there's never a gap.
          // The only clamp is a readability floor for pathologically short
          // screens; if that floor can't be met we just fill what's there.
          double heroHeight = usable * 0.55;
          heroHeight = heroHeight < 160.0 ? 160.0 : heroHeight;
          heroHeight = heroHeight > usable ? usable : heroHeight;

          final double remainingForRows =
              (usable - heroHeight).clamp(0.0, usable);
          double productRowHeight =
              maxProducts > 0 ? remainingForRows / maxProducts : 0.0;
          if (maxProducts > 0 && productRowHeight < 56.0) {
            productRowHeight = 56.0;
          }

          // Rebuild the exact content height from the values above so the
          // box we hand the card always matches what it will actually
          // paint — in the normal case this equals `available` exactly.
          final double cardHeight =
              heroHeight + (productRowHeight * maxProducts) + borderInsets;

          return Center(
            child: ConstrainedBox(
              // Stops the card from stretching edge-to-edge on tablets/web.
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
  // 6. EDITORIAL (single full-screen image, same treatment as hero banner)
  // ---------------------------------------------------------------------

  Widget _editorialSection() {
    return SizedBox(
      height: _fullScreenBannerHeight(context),
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/editorial.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF6B7A5E)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.10),
                  Colors.black.withOpacity(0.30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 7. SHOP BY COLLECTION (same single-image sliding banner as Explore Categories)
  // ---------------------------------------------------------------------

  Widget _shopByCollectionSection() {
    final double bannerHeight =
        (MediaQuery.of(context).size.height * 0.46).clamp(220.0, 420.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sliverHeadAsBox('SHOP BY COLLECTION'),
        _AutoSlideCollectionBanner(
          height: bannerHeight,
          items: _shopByCollectionTiles
              .map((tile) => _SlideItem(
                    image: Image.asset(
                      tile.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFFE0E0E0)),
                    ),
                    label: tile.title,
                    onTap: () => _openCollectionByHandle(
                      tile.handle,
                      title: tile.title,
                      label: tile.title,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 8. INSTAGRAM (5 tappable posts, opens Instagram)
  // ---------------------------------------------------------------------

  Widget _instagramSectionAsBox() {
    final r = R.of(context);
    return SizedBox(
      height: r.dp(140),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
        scrollDirection: Axis.horizontal,
        itemCount: _instagramPosts.length,
        separatorBuilder: (_, __) => SizedBox(width: r.dp(8)),
        itemBuilder: (_, i) {
          final post = _instagramPosts[i];
          return GestureDetector(
            onTap: () => _openInstagramPost(post.postUrl),
            child: SizedBox(
              width: r.dp(140),
              height: r.dp(140),
              child: Image.asset(
                post.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFFE0E0E0)),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Loading / empty states (unchanged)
  // ---------------------------------------------------------------------

  Widget _shimmer() {
    final r = R.of(context);
    return ListView(
      padding: EdgeInsets.all(r.dp(16)),
      children: [
        _sh(r.dp(200), r, radius: 0),
        SizedBox(height: r.dp(16)),
        _sh(r.dp(14), r, width: r.dp(160)),
        SizedBox(height: r.dp(12)),
        Row(
          children: [
            _sh(r.dp(190), r, width: r.dp(150)),
            SizedBox(width: r.dp(12)),
            _sh(r.dp(190), r, width: r.dp(150)),
          ],
        ),
        SizedBox(height: r.dp(20)),
        _sh(r.dp(14), r, width: r.dp(200)),
        SizedBox(height: r.dp(12)),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: r.dp(8),
          mainAxisSpacing: r.dp(8),
          children: List.generate(6, (_) => _sh(double.infinity, r)),
        ),
      ],
    );
  }

  Widget _sh(double height, R r, {double? width, double radius = 0}) =>
      Container(
        height: height,
        width: width,
        decoration: const BoxDecoration(
          color: Color(0xFFE0E0E0),
        ),
      );

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

// ---------------------------------------------------------------------
// Auto-sliding single-image-at-a-time banner (right-to-left transition,
// advances every 5 seconds). Used by Explore Categories and Shop By
// Collection — same look as the full-width hero banner, one item visible
// at a time, with a bottom-left label and a tap handler per slide.
// ---------------------------------------------------------------------

class _SlideItem {
  final Widget image;
  final String label;
  final VoidCallback onTap;
  const _SlideItem({
    required this.image,
    required this.label,
    required this.onTap,
  });
}

class _AutoSlideCollectionBanner extends StatefulWidget {
  final List<_SlideItem> items;
  final double height;
  final Duration interval;
  const _AutoSlideCollectionBanner({
    required this.items,
    required this.height,
    this.interval = const Duration(seconds: 5),
  });

  @override
  State<_AutoSlideCollectionBanner> createState() =>
      _AutoSlideCollectionBannerState();
}

class _AutoSlideCollectionBannerState
    extends State<_AutoSlideCollectionBanner> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    if (widget.items.length > 1) {
      _startAutoSlide();
    }
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      _index = (_index + 1) % widget.items.length;
      _controller.animateToPage(
        _index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
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
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        onPageChanged: (i) => _index = i,
        itemBuilder: (_, i) {
          final item = widget.items[i];
          return GestureDetector(
            onTap: item.onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                item.image,
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.10),
                        Colors.black.withOpacity(0.45),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: r.dp(18),
                  bottom: r.dp(14),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      color: Colors.white,
                      fontSize: r.sp(28),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Shop The Look — each outfit carries its own products. The PageView
// now builds one full card (border + hero image + that outfit's product
// rows) per page, so the whole card slides left as a unit every 5
// seconds instead of only the picture swapping underneath a fixed list.
// ---------------------------------------------------------------------

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

class _ShopTheLookAutoSlideCardState
    extends State<_ShopTheLookAutoSlideCard> {
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
    const accent = Color(0xFF2F6FED);

    if (widget.outfits.isEmpty) {
      return Container(color: const Color(0xFF555555));
    }

    return PageView.builder(
      controller: _controller,
      itemCount: widget.outfits.length,
      onPageChanged: (i) => _index = i,
      itemBuilder: (_, i) {
        final outfit = widget.outfits[i];
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: accent, width: _kCardBorderWidth),
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
                    Positioned(
                      top: r.dp(10),
                      left: r.dp(10),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.dp(10), vertical: r.dp(6)),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.crop_free,
                                size: r.dp(14), color: Colors.white),
                            SizedBox(width: r.dp(6)),
                            Flexible(
                              child: Text(
                                'Scene products item',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.body,
                                  color: Colors.white,
                                  fontSize: r.sp(11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: r.dp(10),
                      right: r.dp(10),
                      child: Container(
                        width: r.dp(28),
                        height: r.dp(28),
                        decoration: const BoxDecoration(
                            color: accent, shape: BoxShape.circle),
                        child: Icon(Icons.add,
                            size: r.dp(18), color: Colors.white),
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
                          color: const Color(0xFFE5E5E5),
                          width: j == 0 ? 1 : 0,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: r.dp(12)),
                    child: Row(
                      children: [
                        Container(
                          width: r.dp(40),
                          height: r.dp(40),
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
                              SizedBox(height: r.dp(1)),
                              Text(
                                'Taxes included Shipping calculated at checkout',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontSize: r.sp(9),
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
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

class _SectionAnchor {
  final String    id;
  final GlobalKey key;
  const _SectionAnchor({required this.id, required this.key});
}

class _PromoCollectionTile {
  final String title;
  final String handle;
  final String imageAsset;
  const _PromoCollectionTile({
    required this.title,
    required this.handle,
    required this.imageAsset,
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
  const _InstagramPost({required this.imageAsset, required this.postUrl});
}