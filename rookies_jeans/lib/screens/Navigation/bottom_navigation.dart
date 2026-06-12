import 'package:flutter/material.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';

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
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          active ? item.activeIcon : item.icon,
                          key: ValueKey(active),
                          size: 22,
                          color: active ? _primary : _inactive,
                        ),
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