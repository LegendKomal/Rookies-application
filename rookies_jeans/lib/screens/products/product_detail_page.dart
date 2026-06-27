import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/product_detail_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';
import 'package:rookies_jeans/services/wishlist_service.dart';
import 'package:rookies_jeans/services/cart_service.dart';
import 'package:rookies_jeans/screens/cart/cart.dart';

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
  static const Color primary      = Color(ShopifyConstants.primaryColorHex);
  static const Color bgColor      = Color(ShopifyConstants.bgColorHex);
  static const Color cardColor    = Color(ShopifyConstants.cardColorHex);
  static const Color secondaryTxt = Color(ShopifyConstants.secondaryTextHex);
  static const Color borderColor  = Color(ShopifyConstants.borderColorHex);

  static const String _fHead = ShopifyConstants.fontHeading;
  static const String _fBody = ShopifyConstants.fontBody;
  static const String _fBold = ShopifyConstants.fontBodyBold;

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

  static const List<String> _highlightKeywords = [
    'COTTON', '100%', 'OVERSIZE', 'OVERSIZED', 'DROP SHOULDER',
    'HALF SLEEVES', 'FULL SLEEVES', 'HALF ZIP', 'CARGO', 'LINEN',
    'STRETCH', 'SLIM FIT', 'REGULAR FIT', 'LOOSE FIT', 'BOOTCUT',
    'BALLOON FIT', 'WHITE', 'BLACK', 'BLUE', 'GREEN', 'BEIGE',
    'MACHINE WASH', 'DRY CLEAN', 'HAND WASH',
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
                itemBuilder: (_, i) => CachedNetworkImage(
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
            style: const TextStyle(
              fontFamily: _fHead,
              fontSize: 22,
              //fontWeight: //fontWeight.w500,
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
          if (p.description.isNotEmpty) ...[
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text(
              'DESCRIPTION',
              style: TextStyle(
                fontFamily: _fBold,
                fontSize: 11,
                //fontWeight: //fontWeight.w800,
                color: primary,
                // letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            _buildHighlightedDescription(p.description),
            const SizedBox(height: 32),
          ],
          if (p.shippingInfo != null && p.shippingInfo!.isNotEmpty) ...[
            const Divider(height: 1),
            _infoTile('SHIPPING', p.shippingInfo!),
          ],
          if (p.careInstructions != null && p.careInstructions!.isNotEmpty) ...[
            const Divider(height: 1),
            _infoTile('CARE INSTRUCTIONS', p.careInstructions!),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildHighlightedDescription(String raw) {
    final lines   = raw.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final isBullet =
          trimmed.startsWith('•') || trimmed.startsWith('-');
      final content =
          isBullet ? trimmed.replaceFirst(RegExp(r'^[•\-]\s*'), '') : trimmed;

      if (isBullet) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3, right: 8),
                child: Icon(Icons.circle, size: 5, color: secondaryTxt),
              ),
              Expanded(child: _highlightedText(content)),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            trimmed,
            style: const TextStyle(
              fontFamily: _fBody,
              fontSize: 13,
              color: secondaryTxt,
              // height: 1.6,
            ),
          ),
        ));
      }
    }

    if (widgets.isEmpty || (widgets.length == 1 && !raw.contains('\n'))) {
      return _highlightedText(raw,
          style: const TextStyle(
            fontFamily: _fBody,
            fontSize: 13,
            color: secondaryTxt,
            height: 1.6,
          ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _highlightedText(String text, {TextStyle? style}) {
    final base = style ??
        const TextStyle(
          fontFamily: _fBody,
          fontSize: 13,
          color: secondaryTxt,
          height: 1.5,
        );

    final colonIdx = text.indexOf(':');
    if (colonIdx > 0 && colonIdx < text.length - 1) {
      final label = text.substring(0, colonIdx + 1).trim();
      final value = text.substring(colonIdx + 1).trim();
      return RichText(
        text: TextSpan(
          style: base,
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontFamily: _fBold,
                //fontWeight: //fontWeight.w700,
                color: primary,
              ),
            ),
            ..._buildHighlightSpans(value, base),
          ],
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: base,
        children: _buildHighlightSpans(text, base),
      ),
    );
  }

  List<InlineSpan> _buildHighlightSpans(String text, TextStyle base) {
    if (text.isEmpty) return [TextSpan(text: text)];

    final pattern = RegExp(
      _highlightKeywords.map(RegExp.escape).join('|'),
      caseSensitive: false,
    );

    final spans  = <InlineSpan>[];
    int   cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          fontFamily: _fBold,
          color: primary,
          //fontWeight: //fontWeight.w700,
          fontSize: base.fontSize,
        ),
      ));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  Widget _goesWellWithSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 16, bottom: 14),
            child: Text(
              'GOES WELL WITH',
              style: TextStyle(
                fontFamily: _fBold,
                fontSize: 11,
                //fontWeight: //fontWeight.w800,
                color: primary,
                // letterSpacing: 1.5,
              ),
            ),
          ),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _goesWellWith.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _pairingCard(_goesWellWith[i]),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _pairingCard(ShopifyProduct product) {
    return GestureDetector(
      onTap: () => _openProductDetail(product),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              child: SizedBox(
                width: 140,
                height: 150,
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
              style: const TextStyle(
                fontFamily: _fBold,
                fontSize: 11,
                //fontWeight: //fontWeight.w700,
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
      return Text(
        product.formattedPrice,
        style: const TextStyle(
          fontFamily: _fBold,
          fontSize: 12,
          //fontWeight: //fontWeight.w700,
          color: primary,
        ),
      );
    }
    return Row(
      children: [
        Text(
          product.formattedPrice,
          style: const TextStyle(
            fontFamily: _fBold,
            fontSize: 12,
            //fontWeight: //fontWeight.w700,
            color: primary,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          product.formattedCompareAtPrice,
          style: const TextStyle(
            fontFamily: _fBold,
            fontSize: 11,
            color: Color(0xFF9A9A9A),
            decoration: TextDecoration.lineThrough,
            decorationColor: Color(0xFF9A9A9A),
          ),
        ),
      ],
    );
  }

  Widget _youMayAlsoLikeSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOU MAY ALSO LIKE',
            style: TextStyle(
              fontFamily: _fBold,
              fontSize: 11,
              //fontWeight: //fontWeight.w800,
              color: primary,
              // letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _youMayAlsoLike.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
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
          Expanded(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: _fBold,
              fontSize: 12,
              //fontWeight: //fontWeight.w700,
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
      return Text(
        product.formattedPrice,
        style: const TextStyle(
          fontFamily: _fBold,
          fontSize: 13,
          //fontWeight: //fontWeight.w700,
          color: primary,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.formattedPrice,
          style: const TextStyle(
            fontFamily: _fBold,
            fontSize: 13,
            //fontWeight: //fontWeight.w700,
            color: primary,
          ),
        ),
        Text(
          product.formattedCompareAtPrice,
          style: const TextStyle(
            fontFamily: _fBold,
            fontSize: 11,
            color: Color(0xFF9A9A9A),
            decoration: TextDecoration.lineThrough,
            decorationColor: Color(0xFF9A9A9A),
          ),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String content) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        iconColor: primary,
        collapsedIconColor: secondaryTxt,
        title: Text(
          label,
          style: const TextStyle(
            fontFamily: _fBold,
            fontSize: 11,
            //fontWeight: //fontWeight.w800,
            color: primary,
            // letterSpacing: 1.5,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              content,
              style: const TextStyle(
                fontFamily: _fBody,
                fontSize: 13,
                color: secondaryTxt,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceBlock(ShopifyProductDetail p) {
    if (!p.isOnSale) {
      return Text(
        p.formattedPrice,
        style: const TextStyle(
          fontFamily: _fBold,
          fontSize: 20,
          //fontWeight: //fontWeight.w800,
          color: primary,
        ),
      );
    }
    final saved    = (p.compareAtPrice! - p.price).round();
    final savedStr =
        p.currencyCode == 'INR' ? '₹$saved' : '${p.currencyCode} $saved';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              p.formattedPrice,
              style: const TextStyle(
                fontFamily: _fBold,
                fontSize: 20,
                //fontWeight: //fontWeight.w800,
                color: primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              p.formattedCompareAtPrice,
              style: const TextStyle(
                fontFamily: _fBold,
                fontSize: 14,
                color: Color(0xFF9A9A9A),
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xFF9A9A9A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            // borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'You save $savedStr',
            style: const TextStyle(
              fontFamily: _fBold,
              fontSize: 11,
              //fontWeight: //fontWeight.w700,
              color: Color(0xFF2E7D32),
            ),
          ),
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
            style: const TextStyle(
              fontFamily: _fBold,
              fontSize: 11,
              //fontWeight: //fontWeight.w700,
              color: primary,
              // letterSpacing: 1.2,
            ),
            children: [
              TextSpan(text: opt.name.toUpperCase()),
              TextSpan(
                text: ' ${_selectedOptions[opt.name] ?? ''}',
                style: const TextStyle(
                  fontFamily: _fBody,
                  //fontWeight: //fontWeight.w500,
                  color: secondaryTxt,
                  // letterSpacing: 0,
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
                  // borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? primary : borderColor,
                    width: isSelected ? 1.5 : 0.8,
                  ),
                ),
                child: Text(
                  val,
                  style: TextStyle(
                    fontFamily: _fBody,
                    fontSize: 12,
                    //fontWeight: //fontWeight.w600,
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
            fontSize: 12,
            //fontWeight: //fontWeight.w600,
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
          height: 50,
          child: ElevatedButton(
            onPressed: !inStock || _isAddingToCart
                ? null
                : alreadyInCart
                    ? _goToCart
                    : _handleAddToCart,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              disabledBackgroundColor: const Color(0xFFCCCCCC),
              // shape: RoundedRectangleBorder(
              //     borderRadius: BorderRadius.circular(8)),
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
                    style: const TextStyle(
                      fontFamily: _fBold,
                      fontSize: 13,
                      //fontWeight: //fontWeight.w800,
                      color: Colors.white,
                      // letterSpacing: 1.5,
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
                        style: const TextStyle(
                          fontFamily: _fBold,
                          fontSize: 12,
                          //fontWeight: //fontWeight.w800,
                          color: primary,
                          // letterSpacing: 1.5,
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
            style: const TextStyle(
              fontFamily: _fBold,
              fontSize: 12,
              //fontWeight: //fontWeight.w800,
              color: primary,
              // letterSpacing: 1.5,
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
                  style: const TextStyle(
                    fontFamily: _fBody,
                    fontSize: 13,
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
                    // shape: RoundedRectangleBorder(
                    //     borderRadius: BorderRadius.circular(6)),
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