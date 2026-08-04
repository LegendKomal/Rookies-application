import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/models/product_detail_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/products/size_chart_view.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';
import 'package:rookies_jeans/services/wishlist_service.dart';
import 'package:rookies_jeans/services/cart_service.dart';
import 'package:rookies_jeans/screens/cart/cart.dart';
import 'package:rookies_jeans/widget/price_text.dart';

class ProductDetailPage extends StatefulWidget {
  final String handle;
  final String? heroImageUrl;
  final String title;

  const ProductDetailPage({
    super.key,
    required this.handle,
    required this.title,
    this.heroImageUrl,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  static const Color primary      = AppColors.primary;
  static const Color bgColor      = AppColors.bg;
  static const Color cardColor    = AppColors.card;
  static const Color secondaryTxt = AppColors.secondaryText;
  static const Color borderColor  = AppColors.border;

  static const String _fHead = AppFonts.heading;
  static const String _fBody = AppFonts.body;
  static const String _fBold = AppFonts.bold;
  static const String _fBodyBold = AppFonts.alteBold;
  static const String _fNumber = AppFonts.number;

  String _numericProductId(String gid) => gid.split('/').last;

  double _s(double base) =>
      Responsive.of(context, baseW: 400, maxScale: 1.25).s(base);
  static const double _maxContentWidth = AppLayout.maxContentMedium;

  ShopifyProductDetail? _product;
  bool _isLoading = true;
  String? _error;
  bool _isWishlisted = false;
  bool _isWishlistLoading = false;
  bool _isAddingToCart = false;

  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  Map<String, String> _selectedOptions = {};
  ProductDetailVariant? _selectedVariant;

  List<ShopifyProduct> _goesWellWith = [];
  List<ShopifyProduct> _youMayAlsoLike = [];
  bool _isLoadingRelated = false;
  int? _expandedTileIndex;

  void _openSizeChart() {
  if (_product == null) return;
  showModalBottomSheet( 
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SizeChartView(
      shop: 'rookiesjeans.myshopify.com', // your actual .myshopify.com domain
      productId: _numericProductId(_product!.id),
      source: 'YOUR_KIWI_SOURCE_ID', // ask Kiwi support for this
      // vendor: _product!.vendor,  // if your model has these
      // type: _product!.productType,
      // tags: _product!.tags.join(','),
    ),
  );
}

  static const List<String> _descLabels = [
    'STYLE NO & COLOR', 'STYLE NO', 'COLLAR/NECK', 'COLLAR / NECK',
    'STRETCH METER', 'WASH CARE', 'FABRIC', 'SLEEVES', 'DESIGN',
    'OCCASION', 'PATTERN', 'POCKETS', 'CLOSURE', 'LENGTH',
    'COLOR', 'CARE', 'FIT',
  ];

  static const Map<String, _PairingConfig> _categoryPairings = {
    'shirt': _PairingConfig(
      label: 'GOES WELL WITH',
      collectionHandles: ['ss26-loose-fit-jeans', 'ss26-bootcutjeans', 'baloon-fit-pants'],
      displayLabel: 'Jeans & Trousers',
    ),
    'tshirt': _PairingConfig(
      label: 'GOES WELL WITH',
      collectionHandles: ['ss26-loose-fit-jeans', 'baloon-fit-pants'],
      displayLabel: 'Bottoms',
    ),
    'jeans': _PairingConfig(
      label: 'GOES WELL WITH',
      collectionHandles: ['ss26-tshirts-oversize-fit-half-sleeve', 'oversized-shirts'],
      displayLabel: 'Tops & Shirts',
    ),
    'pants': _PairingConfig(
      label: 'GOES WELL WITH',
      collectionHandles: ['ss26-tshirts-oversize-fit-half-sleeve', 'oversized-shirts'],
      displayLabel: 'Tops & Shirts',
    ),
    'linen': _PairingConfig(
      label: 'GOES WELL WITH',
      collectionHandles: ['ss26-loose-fit-jeans', 'baloon-fit-pants'],
      displayLabel: 'Relaxed Bottoms',
    ),
  };

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _detectCategory() {
    final combined = '${widget.handle} ${widget.title}'.toLowerCase();
    if (combined.contains('shirt')) return 'shirt';
    if (combined.contains('tshirt') || combined.contains('t-shirt') || combined.contains('tee')) return 'tshirt';
    if (combined.contains('jean') || combined.contains('denim')) return 'jeans';
    if (combined.contains('pant') || combined.contains('trouser') || combined.contains('cargo')) return 'pants';
    if (combined.contains('linen')) return 'linen';
    return 'shirt';
  }

  Future<void> _fetchProduct() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final product = await ShopifyStorefrontService.instance
          .getProductByHandle(widget.handle);

      if (!mounted) return;

      if (product == null) {
        setState(() {
          _error = 'Product not found.';
          _isLoading = false;
        });
        return;
      }

      final defaults = <String, String>{};
      for (final opt in product.options) {
        if (opt.values.isNotEmpty) {
          defaults[opt.name] = opt.values.first;
        }
      }

      setState(() {
        _product = product;
        _selectedOptions = defaults;
        _isWishlisted = WishlistService.instance.isWishlisted(product.id);
        _isLoading = false;
      });

      _updateVariant();
      _fetchRelatedProducts();
    } catch (e, st) {
      debugPrint('ProductDetailPage _fetchProduct error: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load product: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRelatedProducts() async {
    if (!mounted) return;
    setState(() => _isLoadingRelated = true);

    final category = _detectCategory();
    final pairing  = _categoryPairings[category];

    try {
      if (pairing != null && pairing.collectionHandles.isNotEmpty) {
        final handle   = pairing.collectionHandles.first;
        final products = await ShopifyStorefrontService.instance
            .getProductsByCollection(handle, first: 6);
        if (mounted) {
          setState(() => _goesWellWith = products
              .where((p) => p.handle != widget.handle)
              .take(4)
              .toList());
        }
      }

      final similar = await ShopifyStorefrontService.instance
          .getProductsByCollection(_sameCollectionHandle(), first: 8);
      if (mounted) {
        final filtered = similar
            .where((p) => p.handle != widget.handle)
            .toList()
          ..shuffle();
        setState(() => _youMayAlsoLike = filtered.take(6).toList());
      }
    } catch (e) {
      debugPrint('Related products fetch error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingRelated = false);
    }
  }

  String _sameCollectionHandle() {
    final category = _detectCategory();
    switch (category) {
      case 'shirt':
        return widget.handle.contains('oversized')
            ? 'oversized-shirts'
            : 'ss26-linens';
      case 'tshirt':
        return 'ss26-tshirts-oversize-fit-half-sleeve';
      case 'jeans':
        return widget.handle.contains('loose')
            ? 'ss26-loose-fit-jeans'
            : 'ss26-bootcutjeans';
      case 'pants':
        return 'baloon-fit-pants';
      case 'linen':
        return 'ss26-linens';
      default:
        return 'all';
    }
  }

  void _updateVariant() {
    if (_product == null || _product!.variants.isEmpty) return;
    final match = _product!.variants.firstWhere(
      (v) => v.selectedOptions.every(
        (o) => _selectedOptions[o.name] == o.value,
      ),
      orElse: () => _product!.variants.first,
    );
    setState(() => _selectedVariant = match);
  }

  Future<void> _toggleWishlist() async {
    if (_product == null || _isWishlistLoading) return;
    setState(() => _isWishlistLoading = true);
    try {
      final wishlistProduct = ShopifyProduct(
        id: _product!.id,
        title: _product!.title,
        handle: _product!.handle,
        price: _product!.price,
        compareAtPrice: _product!.compareAtPrice,
        currencyCode: _product!.currencyCode,
        imageUrls: List<String>.from(_product!.imageUrls),
        variants: const [],
        options: const [],
      );
      WishlistService.instance.toggleProduct(wishlistProduct);
      if (!mounted) return;
      setState(() =>
          _isWishlisted = WishlistService.instance.isWishlisted(_product!.id));
    } catch (e, st) {
      debugPrint('Wishlist toggle error: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Wishlist error: $e',
          style: const TextStyle(fontFamily: _fBody),
        ),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isWishlistLoading = false);
    }
  }

  void _goToCart() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );

  Future<void> _handleAddToCart() async {
    final variant = _selectedVariant;
    if (variant == null || _isAddingToCart) return;
    if (!variant.availableForSale) return;

    setState(() => _isAddingToCart = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final success = await CartService.instance.addLine(variantId: variant.id);

    if (!mounted) return;
    setState(() => _isAddingToCart = false);
    messenger.showSnackBar(SnackBar(
      content: Text(
        success
            ? '${_product?.title ?? 'Item'} added to cart'
            : 'Failed to add item to cart',
        style: const TextStyle(fontFamily: _fBody),
      ),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
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

  void _openImageViewer(List<String> images) async {
    final returnedIndex = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrls: images,
          initialIndex: _currentImageIndex,
        ),
      ),
    );
    if (!mounted) return;
    if (returnedIndex != null && returnedIndex != _currentImageIndex) {
      _pageController.jumpToPage(returnedIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading
          ? _loadingState()
          : _error != null
              ? _errorState()
              : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final p = _product!;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _imageCarousel(p),
                  _infoSection(p),
                  if (_goesWellWith.isNotEmpty) ...[
                    const Divider(height: 1),
                    _goesWellWithSection(),
                  ],
                  if (_youMayAlsoLike.isNotEmpty) ...[
                    const Divider(height: 1),
                    _youMayAlsoLikeSection(),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imageCarousel(ShopifyProductDetail p) {
    final images = p.imageUrls;
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(children: [
          Container(
            color: const Color(0xFFEEEEEE),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined,
                size: 52, color: Color(0xFFBBBBBB)),
          ),
          _backButton(),
          _wishlistButton(),
        ]),
      );
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _currentImageIndex = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _openImageViewer(images),
                  child: CachedNetworkImage(
                    imageUrl: images[i],
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFFEEEEEE)),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFEEEEEE),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined,
                          size: 52, color: Color(0xFFBBBBBB)),
                    ),
                  ),
                ),
              ),
            ),
            _backButton(),
            _wishlistButton(),
          ]),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentImageIndex == i ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentImageIndex == i
                      ? primary
                      : const Color(0xFFCCCCCC),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _backButton() => Positioned(
        top: 12,
        left: 12,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const SizedBox(
            width: 34,
            height: 34,
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: primary),
          ),
        ),
      );

  Widget _wishlistButton() => Positioned(
        top: 12,
        right: 12,
        child: GestureDetector(
          onTap: _toggleWishlist,
          child: SizedBox(
            width: 38,
            height: 38,
            child: _isWishlistLoading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primary),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      _isWishlisted
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(_isWishlisted),
                      size: 20,
                      color: _isWishlisted ? Colors.red : primary,
                    ),
                  ),
          ),
        ),
      );

  Widget _infoSection(ShopifyProductDetail p) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.title,
            style: TextStyle(
              fontFamily: _fBold,
              fontSize: _s(22),
              color: primary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          _priceBlock(p),
          const SizedBox(height: 16),
          ...p.options.map((opt) => _optionSelector(opt)),
          const SizedBox(height: 20),
          _availabilityChip(),
          const SizedBox(height: 20),
          _addToCartButton(),
          const SizedBox(height: 24),
          // const Divider(height: 1),
          if (p.description.isNotEmpty) ...[
            _descriptionTile(p.description, 0),
            const Divider(height: 1),
          ],
          _infoTile(
            'Shipping & Returns',
            (p.shippingInfo?.isNotEmpty ?? false)
                ? p.shippingInfo!
                : 'Free shipping on prepaid orders. Easy returns within 7 days.',
            1,
          ),
          const Divider(height: 1),
          _infoTile(
            'Care Instructions',
            (p.careInstructions?.isNotEmpty ?? false)
                ? p.careInstructions!
                : 'Machine wash cold. Do not bleach. Tumble dry low.',
            2,
          ),
          // const Divider(height: 1),
          const SizedBox(height: 16),
          GestureDetector(
  onTap: _openSizeChart,
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Size Chart',
          style: TextStyle(fontFamily: _fBold, fontSize: _s(14), color: primary),
        ),
        const Icon(Icons.straighten_rounded, size: 18, color: primary),
      ],
    ),
  ),
),
const Divider(height: 1),
        ],
      ),
    );
  }

  String _preprocessDescription(String raw) {
    var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();

    final sorted = [..._descLabels]
      ..sort((a, b) => b.length.compareTo(a.length));
    final labelPattern = RegExp(
      r'\s*\b(' + sorted.map(RegExp.escape).join('|') + r')\s*:\s*',
      caseSensitive: false,
    );
    text = text.replaceAllMapped(
      labelPattern,
      (m) => '\n${m.group(1)!.toUpperCase()} : ',
    );

    text = text.replaceAll(RegExp(r'\s*\|\s*'), ' | ');
    text = text.replaceAll(RegExp(r'(\s*\|\s*)?"?\s*$', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\s+$', multiLine: true), '');

    return text.trim();
  }

  Widget _descriptionTile(String raw, int index) {
    final cleaned = _preprocessDescription(raw);
    final lines =
        cleaned.split('\n').where((l) => l.trim().isNotEmpty).toList();

    final children = <Widget>[];
    for (final line in lines) {
      final trimmed = line.trim().replaceFirst(RegExp(r'^[•\-]\s*'), '');
      final hasLabel = RegExp(r'^[A-Za-z][A-Za-z\s&/]*:').hasMatch(trimmed);

      if (hasLabel) {
        final colonIdx = trimmed.indexOf(':');
        final label = trimmed.substring(0, colonIdx + 1).trim();
        final value = trimmed.substring(colonIdx + 1).trim();
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6, right: 8),
                child: Icon(Icons.circle, size: 5, color: secondaryTxt),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: _fBody,
                      fontSize: _s(13),
                      color: secondaryTxt,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: '$label ',
                        style: const TextStyle(
                          fontFamily: _fBold,
                          color: primary,
                        ),
                      ),
                      TextSpan(text: value),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            trimmed,
            style: TextStyle(
              fontFamily: _fBody,
              fontSize: _s(13),
              color: secondaryTxt,
              height: 1.6,
            ),
          ),
        ));
      }
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('tile-$index-${_expandedTileIndex == index}'),
        initiallyExpanded: _expandedTileIndex == index,
        onExpansionChanged: (expanded) {
          setState(() => _expandedTileIndex = expanded ? index : null);
        },
        tilePadding: EdgeInsets.zero,
        iconColor: primary,
        collapsedIconColor: secondaryTxt,
        title: Text(
          'Description',
          style: TextStyle(
            fontFamily: _fBold,
            fontSize: _s(14),
            color: primary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String content, int index) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('tile-$index-${_expandedTileIndex == index}'),
        initiallyExpanded: _expandedTileIndex == index,
        onExpansionChanged: (expanded) {
          setState(() => _expandedTileIndex = expanded ? index : null);
        },
        tilePadding: EdgeInsets.zero,
        iconColor: primary,
        collapsedIconColor: secondaryTxt,
        title: Text(
          label,
          style: TextStyle(
            fontFamily: _fBold,
            fontSize: _s(14),
            color: primary,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                content,
                style: TextStyle(
                  fontFamily: _fBody,
                  fontSize: _s(13),
                  color: secondaryTxt,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goesWellWithSection() {
    final cardWidth = _s(140).clamp(120.0, 180.0);
    final imgHeight = _s(150).clamp(130.0, 200.0);
    final listHeight = imgHeight + _s(70).clamp(60.0, 90.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 14),
            child: Text(
              'GOES WELL WITH',
              style: TextStyle(
                fontFamily: _fBold,
                fontSize: _s(22).clamp(20.0, 28.0),
                color: primary,
              ),
            ),
          ),
          SizedBox(
            height: listHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _goesWellWith.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) =>
                  _pairingCard(_goesWellWith[i], cardWidth, imgHeight),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _pairingCard(ShopifyProduct product, double cardWidth, double imgHeight) {
    return GestureDetector(
      onTap: () => _openProductDetail(product),
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              child: SizedBox(
                width: cardWidth,
                height: imgHeight,
                child: product.primaryImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: product.primaryImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFFEEEEEE)),
                        errorWidget: (_, __, ___) =>
                            Container(color: const Color(0xFFEEEEEE)),
                      )
                    : Container(color: const Color(0xFFEEEEEE)),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              product.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: _fBold,
                fontSize: _s(11),
                color: primary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 3),
            _pairingPriceText(product),
          ],
        ),
      ),
    );
  }

  Widget _pairingPriceText(ShopifyProduct product) {
    if (!product.isOnSale) {
      return PriceText(product.formattedPrice, currencyCode: product.currencyCode, fontSize: _s(12), color: primary, amountFontFamily: _fBold);
    }
    return Row(
      children: [
        Flexible(
          child: PriceText(product.formattedPrice, currencyCode: product.currencyCode, fontSize: _s(15), color: primary),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: PriceText(product.formattedCompareAtPrice, currencyCode: product.currencyCode, fontSize: _s(15), color: const Color(0xFF9A9A9A), decoration: TextDecoration.lineThrough),
        ),
      ],
    );
  }

  Widget _youMayAlsoLikeSection() {
    final width = MediaQuery.of(context).size.width;
    final maxTileExtent = width >= 900 ? 240.0 : width >= 600 ? 220.0 : 200.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOU MAY ALSO LIKE',
            style: TextStyle(
              fontFamily: _fBold,
              fontSize: _s(22).clamp(20.0, 28.0),
              color: primary,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _youMayAlsoLike.length,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxTileExtent,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.58,
            ),
            itemBuilder: (_, i) => _alsoLikeCard(_youMayAlsoLike[i]),
          ),
        ],
      ),
    );
  }

  Widget _alsoLikeCard(ShopifyProduct product) {
    return GestureDetector(
      onTap: () => _openProductDetail(product),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.78,
            child: Stack(
              children: [
                Positioned.fill(
                  child: product.primaryImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: product.primaryImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: const Color(0xFFEEEEEE)),
                          errorWidget: (_, __, ___) =>
                              Container(color: const Color(0xFFEEEEEE)),
                        )
                      : Container(color: const Color(0xFFEEEEEE)),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      WishlistService.instance.toggleProduct(product);
                      setState(() {});
                    },
                    child: Icon(
                      WishlistService.instance.isWishlisted(product.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color: WishlistService.instance.isWishlisted(product.id)
                          ? Colors.red
                          : Colors.white,
                      shadows: const [
                        Shadow(blurRadius: 4, color: Colors.black38)
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            product.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: _fBodyBold,
              fontSize: _s(12),
              color: primary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          _alsoLikePriceRow(product),
        ],
      ),
    );
  }

  Widget _alsoLikePriceRow(ShopifyProduct product) {
    if (!product.isOnSale) {
      return PriceText(product.formattedPrice, currencyCode: product.currencyCode, fontSize: _s(15), color: primary);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: PriceText(product.formattedPrice, currencyCode: product.currencyCode, fontSize: _s(15), color: primary),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: PriceText(product.formattedCompareAtPrice, currencyCode: product.currencyCode, fontSize: _s(11), color: const Color(0xFF9A9A9A), amountFontFamily: _fBold, decoration: TextDecoration.lineThrough),
        ),
      ],
    );
  }

  Widget _priceBlock(ShopifyProductDetail p) {
    if (!p.isOnSale) {
      return PriceText(p.formattedPrice, currencyCode: p.currencyCode, fontSize: _s(20), color: primary, amountFontFamily: _fNumber);
    }
    final saved = (p.compareAtPrice! - p.price).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          children: [
            PriceText(p.formattedPrice, currencyCode: p.currencyCode, fontSize: _s(20), color: primary, amountFontFamily: _fNumber),
            PriceText(p.formattedCompareAtPrice, currencyCode: p.currencyCode, fontSize: _s(14), color: const Color(0xFF9A9A9A), amountFontFamily: _fNumber, decoration: TextDecoration.lineThrough),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFF2E7D32).withOpacity(0.1)),
          child: SavedAmountText(saved.toString(), currencyCode: p.currencyCode, fontSize: _s(11), color: const Color(0xFF2E7D32), fontFamily: _fNumber),
        ),
      ],
    );
  }

  Widget _optionSelector(ProductDetailOption opt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontFamily: _fBold,
              fontSize: _s(11),
              color: primary,
            ),
            children: [
              TextSpan(text: opt.name.toUpperCase()),
              TextSpan(
                text: ' ${_selectedOptions[opt.name] ?? ''}',
                style: const TextStyle(
                  fontFamily: _fBody,
                  color: secondaryTxt,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: opt.values.map((val) {
            final isSelected = _selectedOptions[opt.name] == val;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedOptions[opt.name] = val);
                _updateVariant();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? primary : cardColor,
                  border: Border.all(
                    color: isSelected ? primary : borderColor,
                    width: isSelected ? 1.5 : 0.8,
                  ),
                ),
                child: Text(
                  val,
                  style: TextStyle(
                    fontFamily: _fBody,
                    fontSize: _s(12),
                    color: isSelected ? Colors.white : primary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _availabilityChip() {
    final inStock = _selectedVariant?.availableForSale ?? false;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                inStock ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          inStock ? 'In Stock' : 'Out of Stock',
          style: TextStyle(
            fontFamily: _fBody,
            fontSize: _s(12),
            color: inStock
                ? const Color(0xFF2E7D32)
                : const Color(0xFFD32F2F),
          ),
        ),
      ],
    );
  }

  Widget _addToCartButton() {
    final variant = _selectedVariant;
    final inStock = variant?.availableForSale ?? false;
    return AnimatedBuilder(
      animation: CartService.instance,
      builder: (context, _) {
        final alreadyInCart =
            variant != null && CartService.instance.isInCart(variant.id);
        return SizedBox(
          width: double.infinity,
          height: _s(50).clamp(46.0, 60.0),
          child: ElevatedButton(
            onPressed: !inStock || _isAddingToCart
                ? null
                : alreadyInCart
                    ? _goToCart
                    : _handleAddToCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              disabledBackgroundColor: const Color(0xFFCCCCCC),
              elevation: 0,
            ),
            child: _isAddingToCart
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    !inStock
                        ? 'SOLD OUT'
                        : alreadyInCart
                            ? 'GO TO CART'
                            : 'ADD TO CART',
                    style: TextStyle(
                      fontFamily: _fBold,
                      fontSize: _s(13),
                      color: Colors.white,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _loadingState() => Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: cardColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18),
                      color: primary,
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        style: TextStyle(
                          fontFamily: _fBold,
                          fontSize: _s(12),
                          color: primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.heroImageUrl != null)
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: CachedNetworkImage(
                    imageUrl: widget.heroImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: const Color(0xFFEEEEEE)),
                    errorWidget: (_, __, ___) =>
                        Container(color: const Color(0xFFEEEEEE)),
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(color: const Color(0xFFEEEEEE)),
                ),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: primary),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _errorState() => Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: cardColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: primary,
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.title.toUpperCase(),
            style: TextStyle(
              fontFamily: _fBold,
              fontSize: _s(12),
              color: primary,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 52, color: Colors.grey.shade300),
                const SizedBox(height: 14),
                Text(
                  _error ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: _fBody,
                    fontSize: _s(13),
                    color: secondaryTxt,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _fetchProduct,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text(
                    'RETRY',
                    style: TextStyle(fontFamily: _fBold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: const BorderSide(color: primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _PairingConfig {
  final String label;
  final List<String> collectionHandles;
  final String displayLabel;

  const _PairingConfig({
    required this.label,
    required this.collectionHandles,
    required this.displayLabel,
  });
}

class FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  final Map<int, TransformationController> _controllers = {};
  TapDownDetails? _doubleTapDetails;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TransformationController _controllerFor(int index) =>
      _controllers.putIfAbsent(index, () => TransformationController());

  void _handleDoubleTap(int index) {
    final controller = _controllerFor(index);
    if (controller.value != Matrix4.identity()) {
      controller.value = Matrix4.identity();
      setState(() => _isZoomed = false);
    } else if (_doubleTapDetails != null) {
      final position = _doubleTapDetails!.localPosition;
      controller.value = Matrix4.identity()
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        ..scale(2.5);
      setState(() => _isZoomed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: _isZoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => GestureDetector(
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: () => _handleDoubleTap(i),
              child: InteractiveViewer(
                transformationController: _controllerFor(i),
                minScale: 1.0,
                maxScale: 4.0,
                onInteractionEnd: (_) {
                  final zoomed =
                      _controllerFor(i).value != Matrix4.identity();
                  if (zoomed != _isZoomed) {
                    setState(() => _isZoomed = zoomed);
                  }
                },
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrls[i],
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white54),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.image_not_supported_outlined,
                        size: 52,
                        color: Colors.white38),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(context, _currentIndex),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 20, color: Colors.white),
              ),
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}