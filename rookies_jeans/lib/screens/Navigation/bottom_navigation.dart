import 'package:flutter/material.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/services/cart_service.dart';

class RookiesBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const RookiesBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const Color _primary     = Color(ShopifyConstants.primaryColorHex);
  static const Color _inactive    = Color(0xFFAAAAAA);
  static const Color _bg          = Color(ShopifyConstants.cardColorHex);
  static const Color _border      = Color(ShopifyConstants.borderColorHex);
  static const Color _badgeBg     = Color(0xFFD32F2F);

  static const int _cartIndex = 3;

  // static const List<_NavItem> _items = [
  //   _NavItem(label: 'Home',      icon: Icons.home_outlined,           activeIcon: Icons.home_rounded),
  //   _NavItem(label: 'Category',  icon: Icons.grid_view_outlined,      activeIcon: Icons.grid_view_rounded),
  //   _NavItem(label: 'Wishlist',  icon: Icons.favorite_border_rounded,  activeIcon: Icons.favorite_rounded),
  //   _NavItem(label: 'Cart',      icon: Icons.shopping_bag_outlined,   activeIcon: Icons.shopping_bag_rounded),
  //   _NavItem(label: 'Profile',   icon: Icons.person_outline_rounded,  activeIcon: Icons.person_rounded),
  // ];

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_outlined,           activeIcon: Icons.home_rounded),
    _NavItem(icon: Icons.grid_view_outlined,      activeIcon: Icons.grid_view_rounded),
    _NavItem(icon: Icons.favorite_border_rounded,  activeIcon: Icons.favorite_rounded),
    _NavItem(icon: Icons.shopping_bag_outlined,   activeIcon: Icons.shopping_bag_rounded),
    _NavItem(icon: Icons.person_outline_rounded,  activeIcon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item    = _items[i];
              final active  = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _NavIcon(
                        icon: active ? item.activeIcon : item.icon,
                        active: active,
                        showCartBadge: i == _cartIndex,
                        activeColor: _primary,
                        inactiveColor: _inactive,
                        badgeColor: _badgeBg,
                      ),
                      const SizedBox(height: 3),
                      // AnimatedDefaultTextStyle(
                      //   duration: const Duration(milliseconds: 200),
                      //   style: TextStyle(
                      //     fontSize: 10,
                      //     fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      //     color: active ? _primary : _inactive,
                      //     letterSpacing: active ? 0.4 : 0.2,
                      //   ),
                      //   child: Text(item.label),
                      // ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.active,
    required this.showCartBadge,
    required this.activeColor,
    required this.inactiveColor,
    required this.badgeColor,
  });

  final IconData icon;
  final bool active;
  final bool showCartBadge;
  final Color activeColor;
  final Color inactiveColor;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final iconWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(
        icon,
        key: ValueKey(active),
        size: 22,
        color: active ? activeColor : inactiveColor,
      ),
    );

    if (!showCartBadge) return iconWidget;

    return AnimatedBuilder(
      animation: CartService.instance,
      builder: (context, _) {
        final count = CartService.instance.cart.totalQuantity;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            iconWidget,
            if (count > 0)
              Positioned(
                right: -8,
                top: -4,
                child: _CountBadge(count: count, color: badgeColor),
              ),
          ],
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      scale: 1,
      child: Container(
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  // final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem({
    // required this.label,
    required this.icon,
    required this.activeIcon,
  });
}