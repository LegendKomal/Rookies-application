import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';

class ProductsPage extends StatefulWidget {
  final ShopifyCollection collection;

  const ProductsPage({super.key, required this.collection});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  static const Color primary = Color(ShopifyConstants.primaryColorHex);
  static const Color bgColor = Color(ShopifyConstants.bgColorHex);
  static const Color cardColor = Color(ShopifyConstants.cardColorHex);
  static const Color secondaryTxt = Color(ShopifyConstants.secondaryTextHex);
  static const Color borderColor = Color(ShopifyConstants.borderColorHex);

  final ScrollController _scrollController = ScrollController();

  List<ShopifyProduct> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  bool _isAddingToCart = false;
  String? _endCursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInitialProducts();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_isLoading &&
          !_isLoadingMore &&
          _hasNextPage) {
        _loadMoreProducts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _products = [];
        _endCursor = null;
        _hasNextPage = true;
      });
    }

    try {
      final response = await ShopifyStorefrontService.instance
          .getProductsByCollectionPaginated(
        widget.collection.handle,
        first: 24,
      );

      if (!mounted) return;

      setState(() {
        _products = response.products;
        _hasNextPage = response.hasNextPage;
        _endCursor = response.endCursor;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load products. Pull down to retry.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasNextPage) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await ShopifyStorefrontService.instance
          .getProductsByCollectionPaginated(
        widget.collection.handle,
        first: 24,
        after: _endCursor,
      );

      if (!mounted) return;

      setState(() {
        _products.addAll(response.products);
        _hasNextPage = response.hasNextPage;
        _endCursor = response.endCursor;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshProducts() async {
    ShopifyStorefrontService.instance.clearCache();
    await _fetchInitialProducts();
  }

  Future<void> _handleAddToCart(ShopifyProduct product) async {
  if (_isAddingToCart) return;

  setState(() {
    _isAddingToCart = true;
  });

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  bool success = false;
  try {
    success = await ShopifyStorefrontService.instance.addProductToCart(product);
  } catch (_) {
    success = false;
  }

  if (!mounted) return;

  setState(() {
    _isAddingToCart = false;
  });

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        success
            ? '${product.title} added to cart'
            : 'Failed to add item to cart',
      ),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: _isLoading
                  ? _shimmerGrid()
                  : RefreshIndicator(
                      color: primary,
                      onRefresh: _refreshProducts,
                      child: _error != null
                          ? _errorState()
                          : _products.isEmpty
                              ? _emptyState()
                              : _productGrid(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) => Container(
        color: cardColor,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: primary,
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                widget.collection.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primary,
                  letterSpacing: 1.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_products.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_products.length} items',
                  style: const TextStyle(
                    fontSize: 11,
                    color: secondaryTxt,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _productGrid() => GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _products.length + (_isLoadingMore ? 1 : 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.52,
        ),
        itemBuilder: (_, i) {
          if (i >= _products.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _productCard(_products[i]);
        },
      );

  Widget _productCard(ShopifyProduct product) {
    final colorHexes = product.colorHexCodes;

    return GestureDetector(
      onTap: () {
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
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product.primaryImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: product.primaryImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: const Color(0xFFEEEEEE)),
                            errorWidget: (_, __, ___) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                    if (product.isOnSale)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _discountPercent(product),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _priceBlock(product),
                  if (colorHexes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _colorSwatches(colorHexes),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: OutlinedButton(
                      onPressed: _isAddingToCart
                          ? null
                          : () => _handleAddToCart(product),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primary, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                        padding: EdgeInsets.zero,
                        foregroundColor: primary,
                      ),
                      child: _isAddingToCart
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
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
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        color: const Color(0xFFEEEEEE),
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFFBBBBBB),
          size: 32,
        ),
      );

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
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              product.formattedCompareAtPrice,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF9A9A9A),
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xFF9A9A9A),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              product.formattedPrice,
              style: const TextStyle(
                fontSize: 12,
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
          margin: const EdgeInsets.only(right: 4),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
          ),
        );
      }).toList(),
    );
  }

  String _discountPercent(ShopifyProduct product) {
    if (product.compareAtPrice == null || product.compareAtPrice == 0) {
      return 'SALE';
    }
    final pct =
        ((1 - product.price / product.compareAtPrice!) * 100).round();
    return '$pct% OFF';
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            const Text(
              'No products found',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check back soon for new arrivals.',
              style: TextStyle(fontSize: 12, color: secondaryTxt),
            ),
          ],
        ),
      );

  Widget _errorState() => Center(
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
                style: const TextStyle(fontSize: 13, color: secondaryTxt),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _fetchInitialProducts,
                icon: const Icon(Icons.refresh_rounded, size: 16),
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
      );

  Widget _shimmerGrid() => GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 12,
          childAspectRatio: 0.52,
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
}