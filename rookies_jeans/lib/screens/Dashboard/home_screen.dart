import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/banner_model.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/Navigation/bottom_navigation.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';
import 'package:rookies_jeans/screens/authentication/login.dart';

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
  static const Color borderColor  = Color(ShopifyConstants.borderColorHex);

  // ── Bottom nav ──────────────────────────────────────────────────────────────
  int _navIndex = 0;

  // ── Data ────────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  List<HomeBanner>        _banners          = [];
  List<ShopifyCollection> _latestDrop       = [];
  List<ShopifyCollection> _categories       = [];
  List<ShopifyCollection> _ourCollection    = [];
  List<ShopifyProduct>    _oversizedShirts  = [];
  List<ShopifyProduct>    _hotDeals         = [];
  BalloonBannerData?      _balloonBanner;

  // ── Banner carousel ─────────────────────────────────────────────────────────
  late final PageController _bannerCtrl;
  int    _currentBanner = 0;
  Timer? _bannerTimer;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bannerCtrl = PageController();
    _fetchAll();
  }

  @override
  void dispose() {
    _bannerCtrl.dispose();
    _bannerTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Fetch ────────────────────────────────────────────────────────────────────
  Future<void> _fetchAll() async {
    if (mounted) setState(() => _isLoading = true);

    final results = await Future.wait([
      ShopifyStorefrontService.instance.getHomeBanners(),
      ShopifyStorefrontService.instance.getLatestDropCollections(),
      ShopifyStorefrontService.instance.getLatestDropCollections(),
      ShopifyStorefrontService.instance.getOurCollectionTiles(),
      ShopifyStorefrontService.instance
          .getOversizedShirts(first: ShopifyConstants.oversizedShirtsCount),
      ShopifyStorefrontService.instance
          .getHotDeals(first: ShopifyConstants.hotDealsCount),
    ]);

    final balloon =
        await ShopifyStorefrontService.instance.getBalloonBanner();

    if (!mounted) return;
    setState(() {
      _banners         = results[0] as List<HomeBanner>;
      _latestDrop      = results[1] as List<ShopifyCollection>;
      _categories      = results[2] as List<ShopifyCollection>;
      _ourCollection   = results[3] as List<ShopifyCollection>;
      _oversizedShirts = results[4] as List<ShopifyProduct>;
      _hotDeals        = results[5] as List<ShopifyProduct>;
      _balloonBanner   = balloon;
      _isLoading       = false;
    });
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _bannerTimer?.cancel();
    if (_banners.length <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentBanner + 1) % _banners.length;
      _bannerCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut);
    });
  }

  Future<void> _logout() async {
    await ShopifyAuthService.instance.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const Login()));
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      // ── Bottom navigation bar ─────────────────────────────────────────────
      bottomNavigationBar: RookiesBottomNavBar(
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          // TODO: switch page / navigate based on index
          // 0 = Home, 1 = Category, 2 = Wishlist, 3 = Cart, 4 = Profile
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: _isLoading
                  ? _shimmer()
                  : RefreshIndicator(
                      color: primary,
                      onRefresh: _fetchAll,
                      child: CustomScrollView(
                        slivers: [
                          _sliverSearch(),
                          _sliverBanner(),
                          _sliverHead('THE LATEST DROP'),
                          _sliverLatestDrop(),
                          _sliverHead('EXPLORE CATEGORIES'),
                          _sliverCategoriesGrid(),
                          _sliverBalloonBanner(),
                          _sliverHead('OUR COLLECTION'),
                          _sliverOurCollection(),
                          _sliverHead('OVERSIZED SHIRTS'),
                          _sliverOversizedShirts(),
                          if (_hotDeals.isNotEmpty) ...[
                            _sliverHead('HOT DEALS'),
                            _sliverHotDeals(),
                          ],
                          const SliverToBoxAdapter(
                              child: SizedBox(height: 40)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────────
  Widget _topBar() => Container(
        color: cardColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Image.asset('assets/logo.png', height: 15, fit: BoxFit.contain),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.favorite_border_rounded),
              color: primary,
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined),
              color: primary,
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.person_outline_rounded),
              color: primary,
              tooltip: 'Logout',
              onPressed: _logout,
            ),
          ],
        ),
      );

  // ── Search ───────────────────────────────────────────────────────────────────
  Widget _sliverSearch() => SliverToBoxAdapter(
        child: Container(
          color: cardColor,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search',
                hintStyle:
                    TextStyle(color: Color(0xFF9A9A9A), fontSize: 14),
                prefixIcon: Icon(Icons.search,
                    color: Color(0xFF9A9A9A), size: 20),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              ),
            ),
          ),
        ),
      );

  // ── Hero banner ──────────────────────────────────────────────────────────────
  Widget _sliverBanner() {
    final banners = _banners;
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 560,
        child: Stack(
          children: [
            PageView.builder(
              controller: _bannerCtrl,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => _currentBanner = i),
              itemBuilder: (_, i) => _bannerItem(banners[i]),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Center(
                child: _dotIndicator(banners.length, _currentBanner),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerItem(HomeBanner b) => Stack(
        fit: StackFit.expand,
        children: [
          b.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: b.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFF6B7A5E)),
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFF6B7A5E)),
                )
              : Container(color: const Color(0xFF6B7A5E)),

          // top gradient
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

          // bottom gradient
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

          // text + CTA
          Positioned(
            left: 20,
            bottom: 36,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (b.subtitle.isNotEmpty)
                  Text(
                    b.subtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  b.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                if (b.ctaLabel != null) ...[
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      // TODO: navigate to b.ctaUrl
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        b.ctaLabel!,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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

  // ── Section heading ──────────────────────────────────────────────────────────
  Widget _sliverHead(String title) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: primary,
                letterSpacing: 1.8),
          ),
        ),
      );

  // ── Latest drop ──────────────────────────────────────────────────────────────
  Widget _sliverLatestDrop() => SliverToBoxAdapter(
        child: _latestDrop.isEmpty
            ? _empty()
            : SizedBox(
                height: 220,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _latestDrop.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _latestDropTile(_latestDrop[i]),
                ),
              ),
      );

  Widget _latestDropTile(ShopifyCollection collection) {
    const double tileWidth   = 160.0;
    const double imageHeight = 180.0;

    return GestureDetector(
      onTap: () {},
      child: SizedBox(
        width: tileWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: tileWidth,
                height: imageHeight,
                child: collection.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: collection.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFFE0E0E0)),
                        errorWidget: (_, __, ___) =>
                            _collectionPlaceholder(collection.label),
                      )
                    : _collectionPlaceholder(collection.label),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              collection.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectionPlaceholder(String label) => Container(
        color: const Color(0xFFDDDDDD),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  // ── Categories grid ──────────────────────────────────────────────────────────
  Widget _sliverCategoriesGrid() => SliverToBoxAdapter(
        child: _categories.isEmpty
            ? _empty()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (_, i) => _categoryTile(_categories[i]),
                ),
              ),
      );

  Widget _categoryTile(ShopifyCollection cat) => GestureDetector(
        onTap: () {},
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
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // ── Balloon banner ───────────────────────────────────────────────────────────
  Widget _sliverBalloonBanner() {
    final banner = _balloonBanner;
    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () {},
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFFECEEE6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        banner?.title ?? 'BALLOON FIT CARGO PANTS',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: primary,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'BIGGER FIT.\nCOOLER SUMMER.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: primary,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        banner?.description.isNotEmpty == true
                            ? banner!.description
                            : 'New Season Drop',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: secondaryTxt),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          border: Border.all(color: primary),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'EXPLORE NOW',
                          style: TextStyle(
                            color: primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
                child: SizedBox(
                  width: 120,
                  height: 140,
                  child: banner?.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: banner!.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: const Color(0xFFD0D4C8)),
                          errorWidget: (_, __, ___) => Image.asset(
                            'assets/balloon_cargo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: const Color(0xFFD0D4C8)),
                          ),
                        )
                      : Image.asset(
                          'assets/balloon_cargo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: const Color(0xFFD0D4C8)),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Our collection ───────────────────────────────────────────────────────────
  Widget _sliverOurCollection() => SliverToBoxAdapter(
        child: SizedBox(
          height: 110,
          child: _ourCollection.isEmpty
              ? _empty()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _ourCollection.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final col = _ourCollection[i];
                    return GestureDetector(
                      onTap: () {},
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 120,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              col.imageUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: col.imageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                          color: const Color(0xFF555555)),
                                      errorWidget: (_, __, ___) => Container(
                                          color: const Color(0xFF555555)),
                                    )
                                  : Container(
                                      color: const Color(0xFF555555)),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.65),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                bottom: 10,
                                child: Text(
                                  col.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
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

  // ── Oversized shirts ─────────────────────────────────────────────────────────
  Widget _sliverOversizedShirts() => SliverToBoxAdapter(
        child: _oversizedShirts.isEmpty
            ? _empty()
            : SizedBox(
                // taller to fit color swatches + price block + button
                height: 330,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _oversizedShirts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) =>
                      _productTile(_oversizedShirts[i]),
                ),
              ),
      );

  // ── Enhanced product tile ────────────────────────────────────────────────────
  Widget _productTile(ShopifyProduct product) {
    const double tileWidth   = 160.0;
    const double imageHeight = 185.0;

    // Parse color swatches from SA (Size & Color) variants
    final colorHexes = product.colorHexCodes;

    return GestureDetector(
      onTap: () {},
      child: SizedBox(
        width: tileWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product image ───────────────────────────────────────────────
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

            // ── Product title ───────────────────────────────────────────────
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

            // ── Price block: MRP strikethrough + sale price + save badge ────
            _priceBlock(product),

            const SizedBox(height: 6),

            // ── Color swatches from SA variants ────────────────────────────
            if (colorHexes.isNotEmpty) _colorSwatches(colorHexes),

            const SizedBox(height: 8),

            // ── Shop Now button ─────────────────────────────────────────────
            SizedBox(
              width: tileWidth,
              height: 30,
              child: OutlinedButton(
                onPressed: () {
                  // TODO: navigate to product detail page
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primary, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: EdgeInsets.zero,
                  foregroundColor: primary,
                ),
                child: const Text(
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
    );
  }

  /// MRP ₹1,499  ₹1,399  Save ₹100
  Widget _priceBlock(ShopifyProduct product) {
    if (!product.isOnSale) {
      // no sale — just show price
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
        // Row 1: "MRP" + strikethrough price
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

        // Row 2: sale price + "Save ₹X"
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
                color: Color(0xFF2E7D32), // green — "save" colour
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Color swatch circles from SA variant hex codes
  Widget _colorSwatches(List<String> hexCodes) {
    // show at most 5 swatches to avoid overflow
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

  // ── Hot deals ────────────────────────────────────────────────────────────────
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
                              placeholder: (_, __) =>
                                  Container(color: const Color(0xFFE8E8E8)),
                              errorWidget: (_, __, ___) =>
                                  Container(color: const Color(0xFFE8E8E8)),
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

  // ── Shimmer loading ──────────────────────────────────────────────────────────
  Widget _shimmer() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sh(200, radius: 0),
          const SizedBox(height: 16),
          _sh(14, width: 160),
          const SizedBox(height: 12),
          Row(children: [
            _sh(190, width: 150),
            const SizedBox(width: 12),
            _sh(190, width: 150),
          ]),
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

// ── Hot-deals bucket model ────────────────────────────────────────────────────
class _Bucket {
  final String label;
  final Color labelColor;
  const _Bucket(this.label, this.labelColor);
}