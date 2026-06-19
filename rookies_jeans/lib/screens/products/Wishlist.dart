import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/collections/collections.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/screens/products/products.dart';
import 'package:rookies_jeans/services/wishlist_service.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  static const Color primary = Color(ShopifyConstants.primaryColorHex);
  static const Color bgColor = Color(ShopifyConstants.bgColorHex);
  static const Color cardColor = Color(ShopifyConstants.cardColorHex);
  static const Color secondaryTxt = Color(ShopifyConstants.secondaryTextHex);
  static const Color borderColor = Color(ShopifyConstants.borderColorHex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
     appBar: AppBar(
  backgroundColor: cardColor,
  elevation: 0,
  centerTitle: false,
  automaticallyImplyLeading: false,
  titleSpacing: 0,
  title: Row(
    children: [
      IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: primary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      const Text(
        'MY WISHLIST',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: primary,
          letterSpacing: 1.4,
        ),
      ),
    ],
  ),
),
      body: AnimatedBuilder(
        animation: WishlistService.instance,
        builder: (context, _) {
          final products = WishlistService.instance.items;

          if (products.isEmpty) {
            return _emptyWishlistState();
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemBuilder: (context, index) {
              final product = products[index];
              return _wishlistCard(product);
            },
          );
        },
      ),
    );
  }

  Widget _emptyWishlistState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.favorite_border_rounded,
              size: 70,
              color: Color(0xFFBDBDBD),
            ),
            const SizedBox(height: 16),
            const Text(
              'No wishlist items yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Products you like will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: secondaryTxt,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 170,
              height: 42,
              child: OutlinedButton(
                onPressed: _openExploreProducts,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: primary,
                  side: const BorderSide(
                    color: primary,
                    width: 1.1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'EXPLORE PRODUCT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
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

  void _openExploreProducts() {
    // final collection = ShopifyCollection(
    //   id: 'wishlist-explore',
    //   title: 'TRENDING NOW',
    //   handle: ShopifyConstants.trendingNowHandle,
    //   imageUrl: null,
    //   label: 'TRENDING NOW',
    // );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExploreCategoriesPage(),
      ),
    );
  }

  Widget _wishlistCard(ShopifyProduct product) {
    final imageUrl = product.imageUrls.isNotEmpty ? product.imageUrls.first : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(
              handle: product.handle,
              title: product.title,
              heroImageUrl: imageUrl,
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
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: const Color(0xFFEEEEEE),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFFEEEEEE),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 32,
                                  color: Color(0xFFBBBBBB),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFFEEEEEE),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                size: 32,
                                color: Color(0xFFBBBBBB),
                              ),
                            ),
                    ),
                  ),
                  if (_isOnSale(product))
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
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () {
                        WishlistService.instance.removeById(product.id);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.red,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _priceBlock(product),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceBlock(ShopifyProduct product) {
    if (!_isOnSale(product)) {
      return Text(
        _formattedPrice(product),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: primary,
        ),
      );
    }

    final saved = ((product.compareAtPrice ?? 0) - product.price).round();
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
              _formattedCompareAtPrice(product),
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF9A9A9A),
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xFF9A9A9A),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formattedPrice(product),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Save $savedStr',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2E7D32),
          ),
        ),
      ],
    );
  }

  bool _isOnSale(ShopifyProduct product) {
    return product.compareAtPrice != null &&
        product.compareAtPrice! > product.price;
  }

  String _formattedPrice(ShopifyProduct product) {
    return product.currencyCode == 'INR'
        ? '₹${product.price.toStringAsFixed(0)}'
        : '${product.currencyCode} ${product.price.toStringAsFixed(2)}';
  }

  String _formattedCompareAtPrice(ShopifyProduct product) {
    final compareAtPrice = product.compareAtPrice;
    if (compareAtPrice == null) return '';

    return product.currencyCode == 'INR'
        ? '₹${compareAtPrice.toStringAsFixed(0)}'
        : '${product.currencyCode} ${compareAtPrice.toStringAsFixed(2)}';
  }

  String _discountPercent(ShopifyProduct product) {
    final compareAtPrice = product.compareAtPrice;
    if (compareAtPrice == null || compareAtPrice <= 0) {
      return 'SALE';
    }

    final pct = ((1 - (product.price / compareAtPrice)) * 100).round();
    return '$pct% OFF';
  }
}