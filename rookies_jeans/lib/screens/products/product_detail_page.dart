import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/product_detail_model.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';

class ProductDetailPage extends StatefulWidget {
  final String handle;
  final String? heroImageUrl; // passed from grid for instant hero
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

  ShopifyProductDetail? _product;
  bool _isLoading = true;
  String? _error;

  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  // Selected options: { 'Size': 'M', 'Color': 'Blue', ... }
  Map<String, String> _selectedOptions = {};
  ProductDetailVariant? _selectedVariant;

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

  Future<void> _fetchProduct() async {
    if (mounted) setState(() { _isLoading = true; _error = null; });
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
      // Pre-select the first value for each option
      final defaults = <String, String>{};
      for (final opt in product.options) {
        if (opt.values.isNotEmpty) {
          defaults[opt.name] = opt.values.first;
        }
      }
      setState(() {
        _product = product;
        _selectedOptions = defaults;
        _isLoading = false;
      });
      _updateVariant();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load product.';
        _isLoading = false;
      });
    }
  }

  void _updateVariant() {
    if (_product == null) return;
    final match = _product!.variants.firstWhere(
      (v) => v.selectedOptions.every(
          (o) => _selectedOptions[o.name] == o.value),
      orElse: () => _product!.variants.first,
    );
    setState(() => _selectedVariant = match);
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
        // _appBar(p),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _imageCarousel(p),
              _infoSection(p),
            ],
          ),
        ),
      ],
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────

  // SliverAppBar _appBar(ShopifyProductDetail p) => SliverAppBar(
  //       backgroundColor: cardColor,
  //       pinned: true,
  //       elevation: 0,
  //       leading: IconButton(
  //         icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
  //         color: primary,
  //         onPressed: () => Navigator.pop(context),
  //       ),
  //       title: Text(
  //         p.title.toUpperCase(),
  //         style: const TextStyle(
  //           fontSize: 12,
  //           fontWeight: FontWeight.w800,
  //           color: primary,
  //           letterSpacing: 1.5,
  //         ),
  //         overflow: TextOverflow.ellipsis,
  //       ),
  //     );

  // ── Image carousel ───────────────────────────────────────────────────────

  Widget _imageCarousel(ShopifyProductDetail p) {
  final images = p.imageUrls;
  if (images.isEmpty) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Stack(
        children: [
          Container(
            color: const Color(0xFFEEEEEE),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined,
                size: 52, color: Color(0xFFBBBBBB)),
          ),
          _backButton(),
        ],
      ),
    );
  }

  return Column(
    children: [
      AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          children: [
            // ── Images ──
            PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (i) =>
                  setState(() => _currentImageIndex = i),
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

            // ── Back arrow overlay ──
            _backButton(),
          ],
        ),
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
        child: SizedBox(
          width: 34,
          height: 34,
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: primary,
          ),
        ),
      ),
    );

  // ── Info section ─────────────────────────────────────────────────────────

  Widget _infoSection(ShopifyProductDetail p) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            p.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: primary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // Price
          _priceBlock(p),
          const SizedBox(height: 16),

          // Options (Size, Color, etc.)
          ...p.options.map((opt) => _optionSelector(opt)),

          const SizedBox(height: 20),

          // Availability
          _availabilityChip(),
          const SizedBox(height: 20),

          // Add to cart button
          _addToCartButton(),
          const SizedBox(height: 24),

          // Description
          if (p.description.isNotEmpty) ...[
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text(
              'DESCRIPTION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              p.description,
              style: const TextStyle(
                fontSize: 13,
                color: secondaryTxt,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
          ],
          if (p.shippingInfo != null && p.shippingInfo!.isNotEmpty) ...[
  const Divider(height: 1),
  _infoTile('SHIPPING', p.shippingInfo!),
],

// ✅ Care Instructions
if (p.careInstructions != null && p.careInstructions!.isNotEmpty) ...[
  const Divider(height: 1),
  _infoTile('CARE INSTRUCTIONS', p.careInstructions!),
  const SizedBox(height: 32),
],
        ],
      ),
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
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: primary,
          letterSpacing: 1.5,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            content,
            style: const TextStyle(
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
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: primary,
        ),
      );
    }

    final saved =
        (p.compareAtPrice! - p.price).round();
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
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              p.formattedCompareAtPrice,
              style: const TextStyle(
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
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'You save $savedStr',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
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
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: primary,
              letterSpacing: 1.2,
            ),
            children: [
              TextSpan(text: opt.name.toUpperCase()),
              TextSpan(
                text: '  ${_selectedOptions[opt.name] ?? ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: secondaryTxt,
                  letterSpacing: 0,
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? primary : cardColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? primary : borderColor,
                    width: isSelected ? 1.5 : 0.8,
                  ),
                ),
                child: Text(
                  val,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
    final inStock =
        _selectedVariant?.availableForSale ?? false;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: inStock
                ? const Color(0xFF2E7D32)
                : const Color(0xFFD32F2F),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          inStock ? 'In Stock' : 'Out of Stock',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: inStock
                ? const Color(0xFF2E7D32)
                : const Color(0xFFD32F2F),
          ),
        ),
      ],
    );
  }

  Widget _addToCartButton() {
    final inStock =
        _selectedVariant?.availableForSale ?? false;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: inStock
            ? () {
                // TODO: implement add to cart
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Add to cart coming soon!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          disabledBackgroundColor: const Color(0xFFCCCCCC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Text(
          inStock ? 'ADD TO CART' : 'SOLD OUT',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  // ── States ───────────────────────────────────────────────────────────────

  Widget _loadingState() => Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: cardColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                          Icons.arrow_back_ios_new_rounded, size: 18),
                      color: primary,
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: primary,
                          letterSpacing: 1.5,
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
                    child: CircularProgressIndicator(color: primary)),
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
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: primary,
                letterSpacing: 1.5),
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
                  style:
                      const TextStyle(fontSize: 13, color: secondaryTxt),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _fetchProduct,
                  icon:
                      const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('RETRY'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primary,
                    side: const BorderSide(color: primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}