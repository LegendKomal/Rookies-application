import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/models/cart_model.dart';
import 'package:rookies_jeans/screens/cart/checkout_flow.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/services/cart_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static Color get primary      => AppColors.primary;
  static Color get onPrimary    => AppColors.onPrimary;
  static Color get bgColor      => AppColors.bg;
  static Color get cardColor    => AppColors.card;
  static Color get secondaryTxt => AppColors.secondaryText;
  static Color get borderColor  => AppColors.border;
  static Color get fieldFill    => AppColors.fieldFill;
  static Color get hintColor    => AppColors.hint;

  static const String _fHead = AppFonts.heading;
  static const String _fBody = AppFonts.body;
  static const String _fBold = AppFonts.bold;

  double _s(double base) =>
      Responsive.of(context, baseW: 400, maxScale: 1.3).s(base);

  static const double _maxContentWidth = AppLayout.maxContentMedium;

  Widget _centered(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: child,
        ),
      );

  final Set<String> _pendingLineIds = {};
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CartService.instance.refresh();
    });
  }

  void _showToast(String message, {bool isError = false}) =>
      AppToast.show(message, isError: isError);

  Future<void> _changeQuantity(ShopifyCartLine line, int newQuantity) async {
    setState(() => _pendingLineIds.add(line.lineId));
    final ok = await CartService.instance.updateLineQuantity(
      lineId: line.lineId,
      quantity: newQuantity,
    );
    if (!mounted) return;
    setState(() => _pendingLineIds.remove(line.lineId));
    if (!ok) {
      _showToast('Could not update quantity. Try again.', isError: true);
    }
  }

  Future<void> _removeLine(ShopifyCartLine line) async {
    setState(() => _pendingLineIds.add(line.lineId));
    final ok = await CartService.instance.removeLine(lineId: line.lineId);
    if (!mounted) return;
    setState(() => _pendingLineIds.remove(line.lineId));
    if (ok) {
      _showToast('${line.productTitle} removed from cart');
    } else {
      _showToast('Could not remove item. Try again.', isError: true);
    }
  }

  Future<void> _checkout() async {
    if (_isCheckingOut) return;
    setState(() => _isCheckingOut = true);

    try {
      final lines = CartService.instance.cart.lines;
      if (lines.isEmpty) {
        _showToast('Your cart is empty.', isError: true);
        return;
      }

      final placed = await runCheckoutFlow(context, lines: lines);
      if (!mounted) return;

      if (placed) {
        // GoKwik places the order from the website's cart, so the app's
        // Storefront cart is never converted; start a fresh one.
        await CartService.instance.reset();
        if (!mounted) return;
        _showToast('Order placed successfully!');
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: CartService.instance,
          builder: (context, _) {
            final cart      = CartService.instance.cart;
            final isLoading = CartService.instance.isLoading;

            return Column(
              children: [
                _topBar(cart),
                Expanded(
                  child: RefreshIndicator(
                    color: primary,
                    onRefresh: () => CartService.instance.refresh(),
                    child: isLoading && cart.lines.isEmpty
                        ? _loadingState()
                        : cart.lines.isEmpty
                            ? _emptyState()
                            : _cartList(cart),
                  ),
                ),
                if (cart.lines.isNotEmpty) _checkoutBar(cart),
              ],
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _topBar(ShopifyCart cart) {
    final titleSize =
        (MediaQuery.of(context).size.width * 0.09).clamp(22.0, 40.0);
    return Container(
      color: cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: _centered(
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: primary,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
            Expanded(
              child: Text(
                cart.totalQuantity > 0
                    ? 'MY CART (${cart.totalQuantity})'
                    : 'MY CART',
                style: TextStyle(
                  fontSize: titleSize,
                  height: 1,
                  fontFamily: _fHead,
                  color: primary,
                  // letterSpacing: 1.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _loadingState() => Center(
        child: CircularProgressIndicator(color: primary),
      );

  Widget _emptyState() => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: _s(52),
                      color: hintColor,
                    ),
                    SizedBox(height: _s(14)),
                    Text(
                      'Your cart is empty',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _fHead,
                        fontSize: _s(22),
                        fontWeight: FontWeight.w500,
                        color: primary,
                      ),
                    ),
                    SizedBox(height: _s(6)),
                    Text(
                      'Items you add will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _fBody,
                        fontSize: _s(12),
                        color: secondaryTxt,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _cartList(ShopifyCart cart) => _centered(
        ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: cart.lines.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _cartLineCard(cart.lines[i]),
        ),
      );

  Widget _cartLineCard(ShopifyCartLine line) {
    final isPending = _pendingLineIds.contains(line.lineId);

    // Tapping anywhere on the card opens the product; the quantity stepper
    // and delete icon have their own tap handlers, which win over this one.
    return GestureDetector(
      onTap: line.productHandle != null ? () => _openProduct(line) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
      decoration: BoxDecoration(
        color: cardColor,
        // borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
                // borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: _s(80).clamp(72.0, 120.0),
                  height: _s(100).clamp(90.0, 150.0),
                  child: line.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: line.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: fieldFill),
                          errorWidget: (_, __, ___) => Container(
                            color: fieldFill,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 24,
                              color: hintColor,
                            ),
                          ),
                        )
                      : Container(color: fieldFill),
                ),
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.productTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _fBody,
                    fontSize: _s(12),
                    fontWeight: FontWeight.w700,
                    color: primary,
                    height: 1.3,
                  ),
                ),
                if (line.variantTitle != null &&
                    line.variantTitle != 'Default Title') ...[
                  const SizedBox(height: 3),
                  Text(
                    line.variantTitle!,
                    style: TextStyle(
                      fontFamily: _fBody,
                      fontSize: _s(11),
                      color: secondaryTxt,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  line.formattedPrice,
                  style: TextStyle(
                    fontFamily: _fBody,
                    fontSize: _s(13),
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
                if (!line.availableForSale) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Out of stock',
                    style: TextStyle(
                      fontFamily: _fBold,
                      fontSize: _s(11),
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _qtyStepper(line, isPending),
                    const Spacer(),
                    isPending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : GestureDetector(
                            onTap: () => _removeLine(line),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: _s(20),
                              color: secondaryTxt,
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _openProduct(ShopifyCartLine line) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          handle: line.productHandle!,
          title: line.productTitle,
          heroImageUrl: line.imageUrl,
        ),
      ),
    );
  }

  Widget _qtyStepper(ShopifyCartLine line, bool isPending) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          // borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _stepperButton(
              icon: Icons.remove_rounded,
              onTap: isPending
                  ? null
                  : () => _changeQuantity(line, line.quantity - 1),
            ),
            SizedBox(
              width: _s(28),
              child: Text(
                '${line.quantity}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _fBold,
                  fontSize: _s(12),
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ),
            _stepperButton(
              icon: Icons.add_rounded,
              onTap: isPending
                  ? null
                  : () => _changeQuantity(line, line.quantity + 1),
            ),
          ],
        ),
      );

  Widget _stepperButton({required IconData icon, VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        child: SizedBox(
          width: _s(26).clamp(26.0, 40.0),
          height: _s(26).clamp(26.0, 40.0),
          child: Icon(icon, size: _s(14), color: primary),
        ),
      );

  Widget _checkoutBar(ShopifyCart cart) => Container(
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SafeArea(
          top: false,
          child: _centered(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SUBTOTAL',
                          style: TextStyle(
                            fontFamily: _fBold,
                            fontSize: _s(10),
                            fontWeight: FontWeight.w700,
                            color: secondaryTxt,
                            // letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            cart.formattedSubtotal,
                            style: TextStyle(
                              fontFamily: _fBold,
                              fontSize: _s(17),
                              fontWeight: FontWeight.w800,
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: (cart.checkoutUrl == null || _isCheckingOut)
                        ? null
                        : _checkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: onPrimary,
                      shape: const RoundedRectangleBorder(
                          // borderRadius: BorderRadius.circular(8),
                          ),
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: _s(28).clamp(20.0, 40.0),
                        vertical: _s(16).clamp(14.0, 20.0),
                      ),
                    ),
                    child: _isCheckingOut
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onPrimary,
                            ),
                          )
                        : Text(
                            'CHECKOUT',
                            style: TextStyle(
                              fontFamily: _fBold,
                              fontSize: _s(13),
                              fontWeight: FontWeight.w800,
                              color: onPrimary,
                              // letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
