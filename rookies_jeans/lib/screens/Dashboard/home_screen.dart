import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart'; // NEW: needed for Simulation in _NoFlingScrollPhysics
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

  static const double _kBottomNavHeight = 60.0;
  static const double _kShopTheLookToEditorialGap = 24.0;
  static const double _kInstagramBlockSpacing = 2.0;

  // ────────────────────────────────────────────────────────────────────────
  // SNAP-SCROLL CONFIGURATION
  // Tune these to change how the snap feels. `_kSnapThresholdFraction` is
  // the main one: it's the fraction of the CURRENT section's height that
  // the user must scroll past before the page commits to moving to the
  // next/previous section. Lower = snaps on the tiniest nudge,
  // higher = requires a more deliberate scroll.
  // ────────────────────────────────────────────────────────────────────────

  /// Fraction (0.0–1.0) of the current section's height that counts as a
  /// "committed" scroll toward the next/previous section.
  static const double _kSnapThresholdFraction = 0.04;

  /// Absolute floor for the threshold in logical pixels. Guarantees a small
  /// gesture (or a single mouse-wheel tick) is always enough, even on very
  /// short sections.
  static const double _kSnapThresholdMinPx = 12.0;

  /// How long to wait, after the most recent scroll update, before deciding
  /// the gesture has settled and evaluating whether to snap. Acts as a
  /// debounce so a continuous trackpad swipe (which fires many rapid scroll
  /// events) is treated as one gesture instead of many tiny ones.
  static const Duration _kSnapSettleDelay = Duration(milliseconds: 50);   

  static const Duration _kSnapAnimationDuration = Duration(milliseconds: 380);
  static const Curve _kSnapAnimationCurve = Curves.easeOutCubic;

  /// Number of "snap stops" — must match the number of KeyedSubtree(key:
  /// _sectionKeys[i]) entries wired up in build() below.
  static const int _kSectionCount = 8;

  /// Fixed-height spacers that live between measured sections in the sliver
  /// list (see build()) need to be accounted for in the offset table, since
  /// they're not one of the measured sections themselves. Maps
  /// "index of the section right before the gap" -> gap height.
  static const Map<int, double> _kGapAfterSectionIndex = <int, double>{
    4: _kShopTheLookToEditorialGap, // gap between "Shop the look" and "Editorial"
  };

  bool _isLoading = true;
  final ScrollController _scrollCtrl = ScrollController();

  // One GlobalKey per snap-stop section, used to measure its real rendered
  // height after layout (heights here depend on MediaQuery/content, so we
  // measure rather than re-deriving every formula).
  final List<GlobalKey> _sectionKeys =
      List<GlobalKey>.generate(_kSectionCount, (_) => GlobalKey());

  // Scroll offset at which each section begins. Recomputed after layout.
  List<double> _sectionOffsets =
      List<double>.filled(_kSectionCount, 0.0);

  int _currentSectionIndex = 0;
  bool _isSnapping = false;
  double? _gestureBaseOffset;
  Timer? _settleTimer;

  List<ShopifyCollection> _categories = [];

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
    _settleTimer?.cancel(); // NEW
    _scrollCtrl.dispose();
    super.dispose();
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

  // ──────────────────────────────────────────────────────────────────────
  // SNAP-SCROLL LOGIC (NEW)
  // ──────────────────────────────────────────────────────────────────────

  int _clampSectionIndex(int index) {
    if (_sectionOffsets.isEmpty) return 0;
    if (index < 0) return 0;
    if (index > _sectionOffsets.length - 1) return _sectionOffsets.length - 1;
    return index;
  }

  double _clampOffset(double value, double max) {
    if (max < 0) return 0;
    if (value < 0) return 0;
    if (value > max) return max;
    return value;
  }

  /// Measures each section's real rendered height and rebuilds the
  /// cumulative offset table. Safe to call every frame — it only calls
  /// setState when the measured offsets actually changed (e.g. after a
  /// rotation, a font finishing loading, or first layout), so it settles
  /// after at most one extra rebuild instead of looping.
  void _recomputeSectionOffsets() {
    if (!mounted) return;

    final List<double> next = List<double>.filled(_sectionKeys.length, 0.0);
    double running = 0;
    for (int i = 0; i < _sectionKeys.length; i++) {
      next[i] = running;
      final renderObject = _sectionKeys[i].currentContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        running += renderObject.size.height;
      }
      running += _kGapAfterSectionIndex[i] ?? 0.0;
    }

    bool changed = next.length != _sectionOffsets.length;
    if (!changed) {
      for (int i = 0; i < next.length; i++) {
        if ((next[i] - _sectionOffsets[i]).abs() > 0.5) {
          changed = true;
          break;
        }
      }
    }
    if (changed) {
      setState(() => _sectionOffsets = next);
    }
  }

  int _nearestSectionIndexForOffset(double offset) {
    int nearest = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < _sectionOffsets.length; i++) {
      final double distance = (offset - _sectionOffsets[i]).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        nearest = i;
      }
    }
    return nearest;
  }

  double _currentSectionHeight() {
    final int i = _currentSectionIndex;
    final double start = _sectionOffsets[i];
    final double end = i + 1 < _sectionOffsets.length
        ? _sectionOffsets[i + 1]
        : (_scrollCtrl.hasClients
            ? _scrollCtrl.position.maxScrollExtent
            : start);
    final double height = end - start;
    return height < 1.0 ? 1.0 : height;
  }

  void _armSettleTimer() {
    _settleTimer?.cancel();
    _settleTimer = Timer(_kSnapSettleDelay, _evaluateSnap);
  }

  /// Called once a gesture (drag, fling-attempt, or mouse-wheel burst) has
  /// settled. Compares how far the offset moved from the section it
  /// started at against the threshold, then commits to the next, previous,
  /// or the same section.
  void _evaluateSnap() {
    if (!mounted || !_scrollCtrl.hasClients || _sectionOffsets.isEmpty) return;

    final double? base = _gestureBaseOffset;
    _gestureBaseOffset = null;
    if (base == null) return;

    final double delta = _scrollCtrl.offset - base;
    final double dynamicThreshold =
        _currentSectionHeight() * _kSnapThresholdFraction;
    final double threshold = dynamicThreshold > _kSnapThresholdMinPx
        ? dynamicThreshold
        : _kSnapThresholdMinPx;

    int target = _currentSectionIndex;
    if (delta > threshold) {
      target = _currentSectionIndex + 1;
    } else if (delta < -threshold) {
      target = _currentSectionIndex - 1;
    }
    _snapToSection(_clampSectionIndex(target));
  }

  Future<void> _snapToSection(int index) async {
    if (!_scrollCtrl.hasClients || _sectionOffsets.isEmpty) return;

    final int clampedIndex = _clampSectionIndex(index);
    final double maxExtent = _scrollCtrl.position.maxScrollExtent;
    final double rawTarget = clampedIndex == _sectionOffsets.length - 1
        ? maxExtent
        : _sectionOffsets[clampedIndex];
    final double target = _clampOffset(rawTarget, maxExtent);

    _isSnapping = true;
    _currentSectionIndex = clampedIndex;
    try {
      await _scrollCtrl.animateTo(
        target,
        duration: _kSnapAnimationDuration,
        curve: _kSnapAnimationCurve,
      );
    } finally {
      if (mounted) _isSnapping = false;
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_sectionOffsets.isEmpty || !_scrollCtrl.hasClients) return false;

    // A real user drag/swipe just began. If it interrupts an in-flight
    // snap animation, hand control back to the user immediately instead of
    // letting the two animations fight (prevents jitter on rapid/repeated
    // gestures).
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _isSnapping = false;
      _currentSectionIndex = _nearestSectionIndexForOffset(_scrollCtrl.offset);
      _gestureBaseOffset = _sectionOffsets[_currentSectionIndex];
      _settleTimer?.cancel();
      return false;
    }

    // Ignore notifications generated by our own animateTo call.
    if (_isSnapping) return false;

    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _gestureBaseOffset ??= _sectionOffsets[_currentSectionIndex];
      _armSettleTimer();
    }
    return false; // never swallow — RefreshIndicator etc. still need this
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading) {
      // Measure sections after every layout pass; cheap no-op once settled.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _recomputeSectionOffsets());
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? _shimmer()
            : RefreshIndicator(
                color: primary,
                onRefresh: _fetchAll,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: CustomScrollView(
                    controller: _scrollCtrl,
                    // AlwaysScrollableScrollPhysics is preserved (needed for
                    // pull-to-refresh even when content fits on screen);
                    // it now delegates to our no-fling, clamping physics.
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: _NoFlingScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _sectionKeys[0],
                          child: _sliverBannerWithOverlayBar(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _sectionKeys[1],
                          child: _sliverDenimCargoBlocks(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _sectionKeys[2],
                          child: _exploreCategoriesSection(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _sectionKeys[3],
                          child: _sliverBestsellerSalesBlocks(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _sectionKeys[4],
                          child: _shopTheLookSection(),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: _kShopTheLookToEditorialGap),
                      ),
                      SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _sectionKeys[5],
                          child: _editorialSection(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _sectionKeys[6],
                          child: _shopByCollectionSection(),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _sectionKeys[7],
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _sliverCenteredHeadAsBox('FOLLOW US'),
                              _instagramSectionAsBox(),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                          child: SizedBox(height: 40)),
                    ],
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

  /// Editorial section now fills the screen and stops just above the
  /// bottom nav bar, matching how `_shopTheLookSection` sizes itself.
  double _editorialSectionHeight(BuildContext context) =>
      _fullScreenBannerHeight(context) - _kBottomNavHeight;

  double _exploreAndCollectionBannerHeight(BuildContext context) =>
      (MediaQuery.of(context).size.height * 0.9).clamp(220.0, 550.0);

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

  Widget _sliverDenimCargoBlocks() {
    final r = R.of(context);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double blockHeight =
        (MediaQuery.of(context).size.height * 0.46).clamp(220.0, 420.0);
    return Column(
      children: [
        _fullWidthImageBlock(
          assetPath: 'assets/denim.png',
          label: 'Denim',
          width: screenWidth,
          height: blockHeight,
          onTap: () => _openCollectionByHandle('denim',
              title: 'Denim', label: 'DENIM'),
          r: r,
        ),
        _fullWidthImageBlock(
          assetPath: 'assets/cargo.png',
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

  Widget _exploreCategoriesSection() {
    final double bannerHeight = _exploreAndCollectionBannerHeight(context);
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

  Widget _shopTheLookSection() {
    final double sectionHeight =
        _fullScreenBannerHeight(context) - _kBottomNavHeight;
    // final double sectionHeight = _fullScreenBannerHeight(context);

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

          const double borderInsets = _kCardBorderWidth * 2;
          final double usable =
              (available - borderInsets).clamp(0.0, available);

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

          final double cardHeight =
              heroHeight + (productRowHeight * maxProducts) + borderInsets;

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

  Widget _editorialSection() {
    return SizedBox(
      height: _editorialSectionHeight(context),
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

  Widget _shopByCollectionSection() {
    final double bannerHeight = _exploreAndCollectionBannerHeight(context);
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

  Widget _instagramSectionAsBox() {
    final double screenWidth = MediaQuery.of(context).size.width;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < _instagramPosts.length; i++) ...[
          if (i > 0) const SizedBox(height: _kInstagramBlockSpacing),
          _instagramBlock(_instagramPosts[i], screenWidth),
        ],
      ],
    );
  }

  Widget _instagramBlock(_InstagramPost post, double width) {
    return GestureDetector(
      onTap: () => _openInstagramPost(post.postUrl),
      child: SizedBox(
        width: width,
        height: width,
        child: Image.asset(
          post.imageAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Container(color: const Color(0xFFE0E0E0)),
        ),
      ),
    );
  }

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

// ──────────────────────────────────────────────────────────────────────────
// NEW: Scroll physics that disables momentum/fling. When the user releases
// a drag, the scroll stops exactly where the finger lifted (no coasting).
// Our own NotificationListener + animateTo logic then takes over to produce
// the actual smooth snap. This is what stops a single gesture from
// skipping multiple sections and prevents our animation from fighting the
// engine's own ballistic scroll.
// ──────────────────────────────────────────────────────────────────────────
class _NoFlingScrollPhysics extends ClampingScrollPhysics {
  const _NoFlingScrollPhysics({ScrollPhysics? parent}) : super(parent: parent);

  @override
  _NoFlingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _NoFlingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    return null;
  }
}

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