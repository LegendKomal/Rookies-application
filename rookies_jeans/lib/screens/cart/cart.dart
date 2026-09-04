import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/models/address_model.dart';
import 'package:rookies_jeans/models/cart_model.dart';
import 'package:rookies_jeans/screens/cart/checkout.dart';
import 'package:rookies_jeans/screens/profile/address_book.dart';
import 'package:rookies_jeans/services/address_service.dart';
import 'package:rookies_jeans/services/cart_service.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';
import 'package:rookies_jeans/screens/authentication/login.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static Color get primary      => AppColors.primary;
  static Color get bgColor      => AppColors.bg;
  static Color get cardColor    => AppColors.card;
  static Color get secondaryTxt => AppColors.secondaryText;
  static Color get borderColor  => AppColors.border;

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
      final isLoggedIn = await ShopifyAuthService.instance.isLoggedIn();

      if (!isLoggedIn) {
        final loggedInNow = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const Login(isCheckoutFlow: true),
          ),
        );
        if (!mounted) return;
        if (loggedInNow != true) return;
      }

      await AddressService.instance.fetchAddresses();
      if (!mounted) return;

      ShopifyAddress? selectedAddress;

      if (AddressService.instance.addresses.isNotEmpty) {
        selectedAddress = await Navigator.of(context).push<ShopifyAddress>(
          MaterialPageRoute(
            builder: (_) => const AddressBookScreen(pickMode: true),
            fullscreenDialog: true,
          ),
        );
        if (!mounted) return;

        if (selectedAddress == null) return;

        if (!selectedAddress.isDefault) {
          await AddressService.instance.setDefaultAddress(selectedAddress.id);
          if (!mounted) return;
        }
      }
      final token = await ShopifyAuthService.instance.getSavedCustomerToken();
      if (token != null && token.isNotEmpty) {
        final linked = await CartService.instance.linkCheckoutToCustomer(
          customerAccessToken: token,
        );
        if (!mounted) return;
        if (!linked) {
          _showToast(
            'Could not link your account to checkout.',
            isError: true,
          );
        }
      }

      final url = CartService.instance.cart.checkoutUrl;
      if (url == null) {
        if (!mounted) return;
        _showToast('Checkout is not available right now.', isError: true);
        return;
      }

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CheckoutWebView(checkoutUrl: url),
          fullscreenDialog: true,
        ),
      );
      if (!mounted) return;

      if (result == true) {
        await CartService.instance.refresh();
        if (!mounted) return;
        _showToast('Order placed successfully!');
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  void _openImageViewer(String imageUrl, String heroTag) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _ImageZoomViewer(imageUrl: imageUrl, heroTag: heroTag),
        ),
      ),
    );
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

  Widget _loadingState() => const Center(
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
                      color: Colors.grey.shade300,
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
    final heroTag   = 'cart_image_${line.lineId}';

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        // borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: line.imageUrl != null
                ? () => _openImageViewer(line.imageUrl!, heroTag)
                : null,
            child: Hero(
              tag: heroTag,
              child: ClipRRect(
                // borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: _s(80).clamp(72.0, 120.0),
                  height: _s(100).clamp(90.0, 150.0),
                  child: line.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: line.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: const Color(0xFFEEEEEE)),
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFFEEEEEE),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              size: 24,
                              color: Color(0xFFBBBBBB),
                            ),
                          ),
                        )
                      : Container(color: const Color(0xFFEEEEEE)),
                ),
              ),
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
                    fontFamily: _fBold,
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
                    fontFamily: _fBold,
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
                      color: const Color(0xFFD32F2F),
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
        decoration: const BoxDecoration(
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
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'CHECKOUT',
                            style: TextStyle(
                              fontFamily: _fBold,
                              fontSize: _s(13),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
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

class _ImageZoomViewer extends StatefulWidget {
  const _ImageZoomViewer({required this.imageUrl, required this.heroTag});

  final String imageUrl;
  final String heroTag;

  @override
  State<_ImageZoomViewer> createState() => _ImageZoomViewerState();
}

class _ImageZoomViewerState extends State<_ImageZoomViewer> {
  final TransformationController _transformController =
      TransformationController();

  double _dragOffset      = 0;
  double _backdropOpacity = 1;
  bool   _isZoomed        = false;

  static const double _dismissThreshold = 120;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    final scale = _transformController.value.getMaxScaleOnAxis();
    setState(() => _isZoomed = scale > 1.05);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() {
      _dragOffset     += details.delta.dy;
      _backdropOpacity = (1 - (_dragOffset.abs() / 350)).clamp(0.0, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    if (_dragOffset.abs() > _dismissThreshold ||
        details.primaryVelocity!.abs() > 800) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragOffset      = 0;
        _backdropOpacity = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(_backdropOpacity * 1.0),
      body: Stack(
        children: [
          GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
          Center(
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: GestureDetector(
                onVerticalDragUpdate: _onVerticalDragUpdate,
                onVerticalDragEnd: _onVerticalDragEnd,
                child: Hero(
                  tag: widget.heroTag,
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    onInteractionUpdate: _onInteractionUpdate,
                    onInteractionEnd: (_) {
                      final scale =
                          _transformController.value.getMaxScaleOnAxis();
                      setState(() => _isZoomed = scale > 1.05);
                    },
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(
                        width: 80,
                        height: 80,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.image_not_supported_outlined,
                        size: 48,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}