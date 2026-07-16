import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/screens/Navigation/bottom_navigation.dart';
import 'package:rookies_jeans/screens/Dashboard/home_screen.dart';
import 'package:rookies_jeans/screens/authentication/login.dart';
import 'package:rookies_jeans/screens/authentication/register.dart';
import 'package:rookies_jeans/screens/collections/collections.dart';
import 'package:rookies_jeans/screens/orders/orders.dart';
import 'package:rookies_jeans/screens/products/Wishlist.dart';
import 'package:rookies_jeans/screens/cart/cart.dart';
import 'package:rookies_jeans/screens/profile/address_book.dart';
import 'package:rookies_jeans/screens/profile/change_password_screen.dart';
import 'package:rookies_jeans/screens/profile/profile.dart';
import 'package:rookies_jeans/screens/splashscreen/splashscreen.dart';
import 'package:rookies_jeans/services/cart_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  CartService.instance.initialize();

  await AuthService.instance.initialize();

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter _appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const Login(),
    ),

    GoRoute(
  path: '/register',
  builder: (context, state) => const Register(),
),
    GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
    GoRoute(
  path: '/addresses',
  builder: (_, __) => const AddressBookScreen(),
),
    GoRoute(
  path: '/change-password',
  builder: (context, state) => const ChangePasswordScreen(),
),
    GoRoute(
      path: '/data-privacy',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Data & Privacy'))),
    ),
    GoRoute(
      path: '/refund-policy',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Return & Refund Policy'))),
    ),
    GoRoute(
      path: '/shipping-policy',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Shipping Policy'))),
    ),
    GoRoute(
      path: '/store-locator',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Store Locator'))),
    ),
    GoRoute(
      path: '/track-order',
      builder: (context, state) =>
          const Scaffold(body: Center(child: Text('Track Your Order'))),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/category',
            builder: (context, state) => const ExploreCategoriesPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/wishlist',
            builder: (context, state) => const WishlistPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ]),
      ],
    ),
  ],
);

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: RookiesBottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF5F5F3);
    const primary    = Color(0xFF111111);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Rookies',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: primary,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: primary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: primary),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        dividerColor: const Color(0xFFE7E7E7),
      ),
      routerConfig: _appRouter,
    );
  }
}