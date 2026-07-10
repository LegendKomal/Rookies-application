import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/cart/cart.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/screens/products/products.dart';
import 'package:rookies_jeans/screens/search/search.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';
import 'package:rookies_jeans/services/cart_service.dart';
import 'package:rookies_jeans/widget/price_text.dart';
import 'package:video_player/video_player.dart';

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
  static const Color borderColor  = Color.fromARGB(255, 80, 57, 57);
  static const String _fHead = AppFonts.heading;
  static const String _fBody = AppFonts.body;
  static const String _fBold = AppFonts.bold;
  static const String _fNumber = AppFonts.number;
  final Set<String> _addingToCartProductIds = {};
  bool _isLoading = true;
  late VideoPlayerController _videoCtrl;
  bool _videoReady = false;
  final ScrollController _scrollCtrl = ScrollController();
  final List<_SectionAnchor> _sectionAnchors = [];
  bool _isSnapping = false;
  BuildContext? _scrollableContext;
  List<ShopifyCollection> _categories    = [];
  List<ShopifyProduct>    _oversizedShirts = [];
  BalloonBannerData?      _balloonBanner;
  final List<_PromoCollectionTile> _latestDropTiles = const [
    _PromoCollectionTile(
      title: 'NEW ARRIVALS',
      subtitle: 'Fresh picks just landed',
      handle: 'all',
      imageAsset: 'assets/new_arrivals.jpg',
      buttonText: 'SHOP NOW',
    ),
    _PromoCollectionTile(
      title: 'SUMMER EDIT',
      subtitle: 'Lightweight staples for summer',
      handle: 'summer-edit',
      imageAsset: 'assets/summer_edit.jpg',
      buttonText: 'SHOP NOW',
    ),
    _PromoCollectionTile(
      title: 'HOT DEALS',
      subtitle: 'Best prices before they are gone',
      handle: 'hot-deals',
      imageAsset: 'assets/hot_deals.jpg',
      buttonText: 'SHOP NOW',
    ),
    _PromoCollectionTile(
      title: 'TRENDING NOW',
      subtitle: 'Most wanted styles right now',
      handle: 'trending-now',
      imageAsset: 'assets/trending_now.jpg',
      buttonText: 'SHOP NOW',
    ),
  ];
  final List<_PromoCollectionTile> _ourCollectionPromoTiles = const [
    _PromoCollectionTile(
      title: 'OVERSIZED TEES',
      subtitle: 'Relaxed drape. Everyday attitude',
      handle: 'ss26-tshirts-oversize-fit-half-sleeve',
      imageAsset: 'assets/oversized_tees.jpg',
    ),
    _PromoCollectionTile(
      title: 'BALLOON FIT PANTS',
      subtitle: 'Ease in every step',
      handle: 'baloon-fit-pants',
      imageAsset: 'assets/balloon_fit_pants.jpg',
    ),
    _PromoCollectionTile(
      title: 'OVERSIZED SHIRTS',
      subtitle: 'Relaxed cuts. Effortless layering',
      handle: 'oversized-shirts',
      imageAsset: 'assets/oversized_shirts.jpg',
    ),
    _PromoCollectionTile(
      title: 'LINENS',
      subtitle: 'Airy fabric. Summer essential',
      handle: 'ss26-linens',
      imageAsset: 'assets/linens.jpg',
    ),
    _PromoCollectionTile(
      title: 'LOOSE FIT JEANS',
      subtitle: 'Denim that breathes',
      handle: 'ss26-loose-fit-jeans',
      imageAsset: 'assets/loose_fit_jeans.jpg',
    ),
    _PromoCollectionTile(
      title: 'BOOTCUT FIT JEANS',
      subtitle: 'Classic shape. Effortless attitude',
      handle: 'ss26-bootcutjeans',
      imageAsset: 'assets/bootcut_fit_jeans.jpg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _videoCtrl  = VideoPlayerController.asset('assets/rookies_video.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoCtrl.setLooping(true);
        _videoCtrl.setVolume(0);
        _videoCtrl.play();
      });
    _fetchAll();
    CartService.instance.initialize();
  }

  @override
  void dispose() {
    _videoCtrl.dispose();
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
    final results = await Future.wait([
      ShopifyStorefrontService.instance.getLatestDropCollections(),
      ShopifyStorefrontService.instance.getOversizedShirts(
        first: ShopifyConstants.oversizedShirtsCount,
      ),
      ShopifyStorefrontService.instance.getBalloonBanner(),
    ]);
    if (!mounted) return;
    setState(() {
      _categories      = results[0] as List<ShopifyCollection>;
      _oversizedShirts = results[1] as List<ShopifyProduct>;
      _balloonBanner   = results[2] as BalloonBannerData?;
      _isLoading       = false;
    });
  }

  void _openProductDetail(ShopifyProduct product) {
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

  Future<void> _openAssortedCollection() async {
    const assortedCollection = ShopifyCollection(
      id: 'assorted',
      title: 'Assorted',
      handle: 'assorted',
      label: 'ASSORTED',
    );
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ProductsPage(collection: assortedCollection)),
    );
  }

  void _goToCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    );
  }

  Future<bool> _addToCart(ShopifyProduct product, String variantId) async {
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
              : 'Failed to add product to cart',
          style: TextStyle(
            fontFamily: _fBody,
            fontSize: R.of(context).sp(13),
          ),
        ),
        duration: const Duration(seconds: 2),
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
        final r = R.of(sheetContext);
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final selectedVariant = selectedVariantId == null
                ? null
                : product.variants
                    .firstWhere((v) => v.id == selectedVariantId);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                r.dp(20),
                r.dp(20),
                r.dp(20),
                MediaQuery.of(sheetContext).viewInsets.bottom + r.dp(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _fHead,
                      fontSize: r.sp(20),
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  SizedBox(height: r.dp(4)),
                  _priceBlock(product, r),
                  SizedBox(height: r.dp(16)),
                  Text(
                    'SELECT SIZE',
                    style: TextStyle(
                      fontFamily: _fBold,
                      fontSize: r.sp(12),
                      letterSpacing: 1.2,
                      color: secondaryTxt,
                    ),
                  ),
                  SizedBox(height: r.dp(10)),
                  Wrap(
                    spacing: r.dp(10),
                    runSpacing: r.dp(10),
                    children: product.variants.map((variant) {
                      final bool available = variant.availableForSale;
                      final bool selected = variant.id == selectedVariantId;
                      return GestureDetector(
                        onTap: available
                            ? () => setSheetState(
                                () => selectedVariantId = variant.id)
                            : null,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: r.dp(18),
                            vertical: r.dp(10),
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
                              fontSize: r.sp(13),
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
                  SizedBox(height: r.dp(10)),
                  if (selectedVariant != null)
                    Text(
                      selectedVariant.availableForSale
                          ? 'In stock'
                          : 'Out of stock',
                      style: TextStyle(
                        fontFamily: _fBody,
                        fontSize: r.sp(12),
                        color: selectedVariant.availableForSale
                            ? const Color(0xFF2E7D32)
                            : Colors.red,
                      ),
                    ),
                  SizedBox(height: r.dp(20)),
                  SizedBox(
                    width: double.infinity,
                    height: r.dp(46),
                    child: ElevatedButton(
                      onPressed: (selectedVariantId == null || isAdding)
                          ? null
                          : () async {
                              setSheetState(() => isAdding = true);
                              final success = await _addToCart(
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
                          ? SizedBox(
                              width: r.dp(20),
                              height: r.dp(20),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'ADD TO CART',
                              style: TextStyle(
                                fontFamily: _fBold,
                                fontSize: r.sp(13),
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
                            id: 'bestseller_sales',
                            child: _sliverBestsellerSalesBlocks(),
                          ),
                          _snapSection(
                            id: 'categories',
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _sliverHeadAsBox('EXPLORE CATEGORIES'),
                                _categoriesGridAsBox(),
                              ],
                            ),
                          ),
                          _snapSection(
                            id: 'latest_drops',
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _sliverCenteredHeadAsBox('LATEST DROPS'),
                                _latestDropsAsBox(),
                              ],
                            ),
                          ),
                          _snapSection(
                            id: 'balloon_banner',
                            child: _balloonBannerAsBox(),
                          ),
                          _snapSection(
                            id: 'oversized_shirts',
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _sliverHeadAsBox('OVERSIZED SHIRTS'),
                                _oversizedShirtsAsBox(),
                              ],
                            ),
                          ),
                          _snapSection(
                            id: 'our_collections',
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _sliverCenteredHeadAsBox('OUR COLLECTIONS'),
                                _ourCollectionsAsBox(),
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

  Widget _sliverBannerWithOverlayBar() {
    final r = R.of(context);
    return SizedBox(
      height: _fullScreenBannerHeight(context),
      width: double.infinity,
      child: Stack(
        children: [
          _videoBannerItem(),
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
                              onPressed: _logout,
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

  Widget _videoBannerItem() => Stack(
        fit: StackFit.expand,
        children: [
          if (_videoReady)
            ClipRect(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _videoCtrl.value.size.width,
                    height: _videoCtrl.value.size.height,
                    child: VideoPlayer(_videoCtrl),
                  ),
                ),
              ),
            )
          else
            Container(color: const Color(0xFF6B7A5E)),
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
      padding: EdgeInsets.fromLTRB(r.dp(16), r.dp(50), r.dp(16), r.dp(10)),
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

  Widget _categoriesGridAsBox() {
    final r = R.of(context);
    return _categories.isEmpty
        ? _empty()
        : Padding(
            padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _categories.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: r.dp(10),
                crossAxisSpacing: r.dp(10),
                childAspectRatio: 0.80,
              ),
              itemBuilder: (_, i) => _categoryTile(_categories[i], r),
            ),
          );
  }

  Widget _categoryTile(ShopifyCollection cat, R r) => GestureDetector(
        onTap: () => _openCollection(cat),
        child: ClipRRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              cat.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: cat.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: const Color(0xFF555555)),
                      errorWidget: (_, __, ___) =>
                          Container(color: const Color(0xFF555555)),
                    )
                  : Container(color: const Color(0xFF555555)),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.62),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: r.dp(8),
                bottom: r.dp(8),
                child: Text(
                  cat.label,
                  style: TextStyle(
                    fontFamily: _fHead,
                    color: Colors.white,
                    fontSize: r.sp(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _balloonBannerAsBox() {
    final r      = R.of(context);
    final banner = _balloonBanner;
    return GestureDetector(
      onTap: _openAssortedCollection,
      child: Container(
        margin: EdgeInsets.fromLTRB(r.dp(16), r.dp(20), r.dp(16), r.dp(4)),
        height: r.dp(150),
        decoration: const BoxDecoration(),
        child: ClipRRect(
          child: banner?.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: banner!.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFFD0D4C8)),
                  errorWidget: (_, __, ___) => Image.asset(
                    'assets/last-chance-banner.png',
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  'assets/last-chance-banner.png',
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }

  Widget _oversizedShirtsAsBox() {
    final r = R.of(context);
    return _oversizedShirts.isEmpty
        ? _empty()
        : SizedBox(
            height: r.dp(185) + r.dp(7) + r.dp(18) + r.dp(5) + r.dp(30) +
                    r.dp(6) + r.dp(18) + r.dp(8) + r.dp(32),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
              scrollDirection: Axis.horizontal,
              itemCount: _oversizedShirts.length,
              separatorBuilder: (_, __) => SizedBox(width: r.dp(12)),
              itemBuilder: (_, i) => _productTile(_oversizedShirts[i], r),
            ),
          );
  }

  Widget _latestDropsAsBox() {
    final r = R.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _latestDropTiles.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: r.dp(12),
          mainAxisSpacing: r.dp(12),
          childAspectRatio: 0.68,
        ),
        itemBuilder: (_, i) => _latestDropCard(_latestDropTiles[i], r),
      ),
    );
  }

  Widget _latestDropCard(_PromoCollectionTile tile, R r) => GestureDetector(
        onTap: () => _openCollectionByHandle(
          tile.handle,
          title: tile.title,
          label: tile.title,
        ),
        child: ClipRRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                tile.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF555555)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.10),
                      Colors.black.withOpacity(0.42),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: r.dp(16),
                right: r.dp(16),
                bottom: r.dp(18),
                child: Column(
                  children: [
                    Text(
                      tile.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _fHead,
                        color: Colors.white,
                        fontSize: r.sp(30),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: r.dp(8)),
                    SizedBox(
                      height: r.dp(42),
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _openCollectionByHandle(
                          tile.handle,
                          title: tile.title,
                          label: tile.title,
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.white,
                            width: 1,
                          ),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: r.dp(10)),
                          shape: RoundedRectangleBorder(),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tile.buttonText,
                              style: TextStyle(
                                fontFamily: _fBold,
                                fontSize: r.sp(15),
                              ),
                            ),
                            SizedBox(width: r.dp(6)),
                            Text(
                              '→',
                              style: TextStyle(
                                fontSize: r.sp(11),
                                height: 1.1,
                              ),
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
      );

  Widget _ourCollectionsAsBox() {
    final r = R.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.dp(16)),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: _ourCollectionPromoTiles.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
          childAspectRatio: 0.68,
        ),
        itemBuilder: (_, i) =>
            _ourCollectionCard(_ourCollectionPromoTiles[i], i, r),
      ),
    );
  }

  Widget _ourCollectionCard(_PromoCollectionTile tile, int index, R r) =>
      GestureDetector(
        onTap: () => _openCollectionByHandle(
          tile.handle,
          title: tile.title,
          label: tile.title,
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: borderColor,
                width: index < 2 ? 1 : 0.8,
              ),
              left: BorderSide(
                color: borderColor,
                width: index.isEven ? 1 : 0.4,
              ),
              right: const BorderSide(color: borderColor, width: 0.8),
              bottom: const BorderSide(color: borderColor, width: 0.8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: const Color(0xFFF5F5F5),
                padding: EdgeInsets.fromLTRB(
                    r.dp(8), r.dp(12), r.dp(8), r.dp(10)),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tile.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: _fHead,
                          fontSize: r.sp(15),
                          fontWeight: FontWeight.w500,
                          color: primary,
                        ),
                      ),
                    ),
                    SizedBox(height: r.dp(4)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.dp(4)),
                      child: Text(
                        tile.subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: _fBold,
                          fontSize: r.sp(13),
                          color: secondaryTxt,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Image.asset(
                  tile.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFFE0E0E0)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _productTile(ShopifyProduct product, R r) {
    final double tileWidth   = r.dp(160);
    final double imageHeight = r.dp(185);
    final colorHexes = product.colorHexCodes;
    return GestureDetector(
      onTap: () => _openProductDetail(product),
      child: SizedBox(
        width: tileWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              child: SizedBox(
                width: tileWidth,
                height: imageHeight,
                child: product.primaryImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: product.primaryImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFFE0E0E0)),
                        errorWidget: (_, __, ___) =>
                            Container(color: const Color(0xFFE0E0E0)),
                      )
                    : Container(color: const Color(0xFFE0E0E0)),
              ),
            ),
            SizedBox(height: r.dp(7)),
            Text(
              product.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _fBody,
                fontSize: r.sp(13),
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
            SizedBox(height: r.dp(5)),
            _priceBlock(product, r),
            SizedBox(height: r.dp(6)),
            if (colorHexes.isNotEmpty) _colorSwatches(colorHexes, r),
            SizedBox(height: r.dp(8)),
            _cartButtonForProduct(product, r),
          ],
        ),
      ),
    );
  }

  Widget _cartButtonForProduct(ShopifyProduct product, R r) {
    return AnimatedBuilder(
      animation: CartService.instance,
      builder: (context, _) {
        final inCart = product.variants
            .any((v) => CartService.instance.isInCart(v.id));
        final isBusy = _addingToCartProductIds.contains(product.id);
        return SizedBox(
          width: double.infinity,
          height: r.dp(32),
          child: OutlinedButton(
            onPressed: isBusy
                ? null
                : inCart
                    ? _goToCart
                    : () => _showSizeSelector(product),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: primary, width: 1.2),
              shape: const RoundedRectangleBorder(),
              padding: EdgeInsets.zero,
              foregroundColor: primary,
            ),
            child: Text(
              inCart ? 'GO TO CART' : 'SHOP NOW',
              style: TextStyle(
                fontFamily: _fBold,
                fontSize: r.sp(11),
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _priceBlock(ShopifyProduct product, R r) {
    if (!product.isOnSale) {
      return PriceText(product.formattedPrice, currencyCode: product.currencyCode, fontSize: r.sp(14), color: primary, amountFontFamily: _fNumber);
    }
    final saved = (product.compareAtPrice! - product.price).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('MRP ', style: TextStyle(fontFamily: _fBody, fontSize: r.sp(11), fontWeight: FontWeight.w500, color: const Color(0xFF9A9A9A))),
            PriceText(product.formattedCompareAtPrice, currencyCode: product.currencyCode, fontSize: r.sp(12), color: const Color(0xFF9A9A9A), amountFontFamily: _fNumber, decoration: TextDecoration.lineThrough),
          ],
        ),
        SizedBox(height: r.dp(2)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PriceText(product.formattedPrice, currencyCode: product.currencyCode, fontSize: r.sp(15), color: primary, amountFontFamily: _fNumber),
            SizedBox(width: r.dp(6)),
            SavedAmountText(saved.toString(), currencyCode: product.currencyCode, fontSize: r.sp(11), color: const Color(0xFF2E7D32), fontFamily: _fNumber),
          ],
        ),
      ],
    );
  }

  Widget _colorSwatches(List<String> hexCodes, R r) {
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
          margin: EdgeInsets.only(right: r.dp(5)),
          width:  r.dp(18),
          height: r.dp(18),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFDDDDDD),
              width: 1,
            ),
          ),
        );
      }).toList(),
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

class _SectionAnchor {
  final String    id;
  final GlobalKey key;
  const _SectionAnchor({required this.id, required this.key});
}

class _PromoCollectionTile {
  final String title;
  final String subtitle;
  final String handle;
  final String imageAsset;
  final String buttonText;
  const _PromoCollectionTile({
    required this.title,
    required this.subtitle,
    required this.handle,
    required this.imageAsset,
    this.buttonText = 'SHOP NOW',
  });
}