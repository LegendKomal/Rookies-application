import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/banner_model.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/cart/cart.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/screens/products/products.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';
import 'package:rookies_jeans/services/cart_service.dart';
import 'package:rookies_jeans/screens/authentication/login.dart';
import 'package:video_player/video_player.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primary      = Color(ShopifyConstants.primaryColorHex);
  static const Color bgColor      = Color(ShopifyConstants.bgColorHex);
  static const Color cardColor    = Color(ShopifyConstants.cardColorHex);
  static const Color secondaryTxt = Color(ShopifyConstants.secondaryTextHex);
  static const Color borderColor  = Color.fromARGB(255, 80, 57, 57);

  final Set<String> _addingToCartProductIds = {};

  bool _isLoading = true;

  late VideoPlayerController _videoCtrl;
  bool _videoReady = false;

  final ScrollController _scrollCtrl = ScrollController();
  final List<_SectionAnchor> _sectionAnchors = [];
  bool _isSnapping = false;

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
      final scrollBox = _scrollableContext?.findRenderObject() as RenderBox?;
      if (scrollBox == null) continue;
      final position = box.localToGlobal(Offset.zero, ancestor: scrollBox);
      offsets.add(_scrollCtrl.offset + position.dy);
    }
    offsets.sort();
    return offsets;
  }

  BuildContext? _scrollableContext;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification && !_isSnapping) {
      _snapToNearestSection();
    }
    return false;
  }

  Future<void> _snapToNearestSection() async {
    final offsets = _collectSectionOffsets();
    if (offsets.isEmpty) return;

    final current = _scrollCtrl.offset;
    final maxScroll = _scrollCtrl.position.maxScrollExtent;

    double nearest = offsets.first;
    double bestDelta = (offsets.first - current).abs();
    for (final o in offsets) {
      final delta = (o - current).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        nearest = o;
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

  void _goToCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CartScreen(),
      ),
    );
  }

  Future<void> _addToCart(ShopifyProduct product) async {
    if (_addingToCartProductIds.contains(product.id)) return;
    if (product.variants.isEmpty) return;

    setState(() => _addingToCartProductIds.add(product.id));

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final success = await CartService.instance.addLine(
      variantId: product.variants.first.id,
    );

    if (!mounted) return;
    setState(() => _addingToCartProductIds.remove(product.id));

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '${product.title} added to cart'
              : 'Failed to add product to cart',
        ),
        duration: const Duration(seconds: 2),
        // action: success
        //     ? SnackBarAction(
        //         label: 'GO TO CART',
        //         onPressed: _goToCart,
        //       )
        //     : null,
      ),
    );
  }

  List<ShopifyCollection> _latestDrop    = [];
  List<ShopifyCollection> _categories    = [];
  List<ShopifyCollection> _ourCollection = [];
  List<ShopifyProduct>    _oversizedShirts = [];
  List<ShopifyProduct>    _hotDeals        = [];
  BalloonBannerData?      _balloonBanner;

  late final PageController _bannerCtrl;
  int    _currentBanner = 0;
  Timer? _bannerTimer;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _videoCtrl = VideoPlayerController.asset('assets/rookies_video.mp4')
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
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll({bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoading = true);

    if (forceRefresh) {
      ShopifyStorefrontService.instance.clearCache();
    }

    final results = await Future.wait([
      ShopifyStorefrontService.instance.getLatestDropCollections(),
      ShopifyStorefrontService.instance.getOurCollectionTiles(),
      ShopifyStorefrontService.instance.getOversizedShirts(
          first: ShopifyConstants.oversizedShirtsCount),
      ShopifyStorefrontService.instance.getHotDeals(
          first: ShopifyConstants.hotDealsCount),
      ShopifyStorefrontService.instance.getBalloonBanner(),
    ]);

    if (!mounted) return;
    setState(() {
      _latestDrop      = results[0] as List<ShopifyCollection>;
      _categories      = results[0] as List<ShopifyCollection>;
      _ourCollection   = results[1] as List<ShopifyCollection>;
      _oversizedShirts = results[2] as List<ShopifyProduct>;
      _hotDeals        = results[3] as List<ShopifyProduct>;
      _balloonBanner   = results[4] as BalloonBannerData?;
      _isLoading       = false;
    });
  }

  void _openCollection(ShopifyCollection collection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsPage(collection: collection),
      ),
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
                            id: 'shop_by_fit',
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _sliverHeadAsBox('SHOP BY FIT'),
                                _shopByFitAsBox(),
                              ],
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
      child: KeyedSubtree(
        key: key,
        child: child,
      ),
    );
  }

  double _fullScreenBannerHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.size.height - mq.padding.top - mq.padding.bottom;
  }

  Widget _sliverBannerWithOverlayBar() => SizedBox(
        height: _fullScreenBannerHeight(context),
        width: double.infinity,
        child: Stack(
          children: [
            _videoBannerItem(),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 80,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.search, size: 22),
                            color: Colors.white,
                            onPressed: () {},
                          ),
                        ),
                      ),
                      Image.asset(
                        'assets/logo2.png',
                        height: 14,
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
                                icon: const Icon(Icons.favorite_border_rounded, size: 22),
                                color: Colors.white,
                                 onPressed: () => context.go('/wishlist'),
                              ),
                              // _cartIconWithBadge(),
                              IconButton(
                                icon: const Icon(Icons.person_outline_rounded, size: 22),
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

  Widget _cartIconWithBadge() => AnimatedBuilder(
        animation: CartService.instance,
        builder: (context, _) {
          final count = CartService.instance.totalQuantity;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, size: 22),
                color: Colors.white,
                onPressed: _goToCart,
              ),
              if (count > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );

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

  Widget _dotIndicator(int count, int current) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 15 : 8,
            height: 4,
            decoration: BoxDecoration(
              color: i == current ? primary : const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );

  Widget _sliverHeadAsBox(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: primary,
              letterSpacing: 1.8,
            ),
          ),
        ),
      );

  Widget _sliverBestsellerSalesBlocks() {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenWidth = screenSize.width;
    final double blockHeight =
        (screenSize.height * 0.40).clamp(220.0, 420.0);

    return Column(
      children: [
        _fullWidthImageBlock(
          assetPath: 'assets/bestseller.jpg',
          label: 'Bestseller',
          width: screenWidth,
          height: blockHeight,
          onTap: () {},
        ),
        _fullWidthImageBlock(
          assetPath: 'assets/sales.jpg',
          label: 'Sales',
          width: screenWidth,
          height: blockHeight,
          onTap: () {},
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
              left: 18,
              bottom: 18,
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoriesGridAsBox() => _categories.isEmpty
      ? _empty()
      : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (_, i) => _categoryTile(_categories[i]),
          ),
        );

  Widget _categoryTile(ShopifyCollection cat) => GestureDetector(
        onTap: () => _openCollection(cat),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
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
                left: 8,
                bottom: 8,
                child: Text(
                  cat.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  static const List<String> _fitAssets = [
    'assets/jeans1.jpeg',
    'assets/jeans2.jpeg',
    'assets/jeans3.jpeg',
    'assets/jeans4.jpeg',
    'assets/jeans5.jpeg',
  ];

  static const List<String> _fitLabels = [
    'Slim Fit',
    'Regular Fit',
    'Baggy Fit',
    'Straight Fit',
    'Oversized Fit',
  ];

  Widget _shopByFitAsBox() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: 4,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.90,
              ),
              itemBuilder: (_, i) => _fitTile(_fitAssets[i], _fitLabels[i]),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 170,
              child: _fitTile(_fitAssets[4], _fitLabels[4]),
            ),
          ],
        ),
      );

  Widget _fitTile(String assetPath, String label) => GestureDetector(
        onTap: () {},
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                assetPath,
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
                      Colors.transparent,
                      Colors.black.withOpacity(0.62),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _balloonBannerAsBox() {
    final banner = _balloonBanner;
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
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

  Widget _oversizedShirtsAsBox() => _oversizedShirts.isEmpty
      ? _empty()
      : SizedBox(
          height: 330,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _oversizedShirts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _productTile(_oversizedShirts[i]),
          ),
        );

  Widget _productTile(ShopifyProduct product) {
    const double tileWidth = 160.0;
    const double imageHeight = 185.0;
    final colorHexes = product.colorHexCodes;
    final isAdding = _addingToCartProductIds.contains(product.id);
    final variantId = product.variants.isNotEmpty ? product.variants.first.id : null;

    return GestureDetector(
      onTap: () => _openProductDetail(product),
      child: SizedBox(
        width: tileWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 7),
            Text(
              product.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
            const SizedBox(height: 5),
            _priceBlock(product),
            const SizedBox(height: 6),
            if (colorHexes.isNotEmpty) _colorSwatches(colorHexes),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: CartService.instance,
              builder: (context, _) {
                final isAddedToCart =
                    variantId != null && CartService.instance.isInCart(variantId);

                return SizedBox(
                  width: tileWidth,
                  height: 30,
                  child: OutlinedButton(
                    onPressed: isAdding
                        ? null
                        : () async {
                            if (isAddedToCart) {
                              _goToCart();
                            } else {
                              await _addToCart(product);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primary, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: EdgeInsets.zero,
                      foregroundColor: primary,
                    ),
                    child: isAdding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isAddedToCart ? 'GO TO CART' : 'SHOP NOW',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: primary,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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
          children: [
            const Text(
              'MRP ',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9A9A9A),
              ),
            ),
            Text(
              product.formattedCompareAtPrice,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF9A9A9A),
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xFF9A9A9A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              product.formattedPrice,
              style: const TextStyle(
                fontSize: 13,
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
          margin: const EdgeInsets.only(right: 5),
          width: 18,
          height: 18,
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

  Widget _sliverHotDeals() {
    const buckets = [
      _Bucket('STYLES UNDER ₹999',  Color(0xFF111111)),
      _Bucket('STYLES UNDER ₹1499', Color(0xFF8B4513)),
      _Bucket('STYLES UNDER ₹1999', Color(0xFFFF3B3B)),
      _Bucket('STYLES UNDER ₹2999', Color(0xFF111111)),
    ];
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 175,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: buckets.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final product = i < _hotDeals.length ? _hotDeals[i] : null;
            return GestureDetector(
              onTap: () {},
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 130,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      product?.primaryImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: product!.primaryImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                  color: const Color(0xFFE8E8E8)),
                              errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xFFE8E8E8)),
                            )
                          : Container(color: const Color(0xFFE8E8E8)),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 7),
                          color: buckets[i].labelColor,
                          child: Text(
                            buckets[i].label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _shimmer() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sh(200, radius: 0),
          const SizedBox(height: 16),
          _sh(14, width: 160),
          const SizedBox(height: 12),
          Row(
            children: [
              _sh(190, width: 150),
              const SizedBox(width: 12),
              _sh(190, width: 150),
            ],
          ),
          const SizedBox(height: 20),
          _sh(14, width: 200),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: List.generate(6, (_) => _sh(double.infinity)),
          ),
        ],
      );

  Widget _sh(double height, {double? width, double radius = 8}) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  Widget _empty() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Text(
            'Nothing here yet.',
            style: TextStyle(color: secondaryTxt, fontSize: 13),
          ),
        ),
      );
}

class _SectionAnchor {
  final String id;
  final GlobalKey key;
  const _SectionAnchor({required this.id, required this.key});
}

class _Bucket {
  final String label;
  final Color  labelColor;
  const _Bucket(this.label, this.labelColor);
}