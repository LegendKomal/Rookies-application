import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
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
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/screens/search/search_tab_page.dart';
import 'package:rookies_jeans/screens/splashscreen/splashscreen.dart';
import 'package:rookies_jeans/services/cart_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  CartService.instance.initialize();

  await AuthService.instance.initialize();
  await ThemeService.instance.initialize();

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
    GoRoute(path: '/wishlist', builder: (_, __) => const WishlistPage()),
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
    // Matches the /products/:handle path of shared product links
    // (https://rookiesjeans.com/products/<handle>) so tapping one when the
    // app is installed opens this page instead of falling through to the
    // browser. Title is unknown until ProductDetailPage fetches the
    // product, so the handle is shown as a placeholder while loading.
    GoRoute(
      path: '/products/:handle',
      builder: (context, state) => ProductDetailPage(
        handle: state.pathParameters['handle']!,
        title: state.pathParameters['handle']!,
      ),
    ),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // Branch order must match the visual icon order in
        // RookiesBottomNavBar (menu, search, home, profile, cart) so that
        // navigationShell.currentIndex highlights the correct icon.
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/category',
            builder: (context, state) => const ExploreCategoriesPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchTabPage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/cart',
            builder: (context, state) => const CartScreen(),
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
      extendBody: true,
      // This Scaffold's background is what shows through any gap behind
      // the floating glass pill (rounded corners, blur edges) and through
      // any space below content that doesn't fill the screen. Previously
      // this fell back to the app theme's `scaffoldBackgroundColor`
      // (0xFFF5F5F3, an off-white/cream), which is what produced the
      // visible whitish strip above the nav bar. Set it explicitly to
      // black so it blends with the dark photography instead.
      backgroundColor: Colors.black,
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

    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Rookies',
          themeMode: ThemeService.instance.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
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
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: primary,
              contentTextStyle: TextStyle(color: Colors.white),
              actionTextColor: Colors.white,
              behavior: SnackBarBehavior.floating,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              secondary: Colors.white,
              surface: Color(0xFF1E1E1E),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              foregroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              centerTitle: true,
            ),
            progressIndicatorTheme:
                const ProgressIndicatorThemeData(color: Colors.white),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            dividerColor: const Color(0xFF2C2C2C),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: Colors.white,
              contentTextStyle: TextStyle(color: Color(0xFF121212)),
              actionTextColor: Color(0xFF121212),
              behavior: SnackBarBehavior.floating,
            ),
          ),
          routerConfig: _appRouter,
        );
      },
    );
  }
}