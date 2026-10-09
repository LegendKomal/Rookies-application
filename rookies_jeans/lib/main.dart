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
import 'package:rookies_jeans/services/recently_viewed_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  CartService.instance.initialize();
  RecentlyViewedService.instance.initialize();

  // Show the splash video right away; sign-in (which can hit the network)
  // and theme loading finish while it plays, and the splash waits for them
  // before opening home.
  SplashScreen.startup = Future.wait([
    AuthService.instance.initialize(),
    ThemeService.instance.initialize(),
  ]);

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// One navigator per bottom-nav branch, in the same order as the branches
/// below. Kept here so a nav-bar tap can pop whatever was pushed inside a
/// tab (e.g. a product opened from Home) back to that tab's root page.
final List<GlobalKey<NavigatorState>> _branchNavigatorKeys = List.generate(
  5,
  (i) => GlobalKey<NavigatorState>(debugLabel: 'branch$i'),
);

/// Index of the Home branch in the StatefulShellRoute below.
const int _homeBranchIndex = 2;

/// A top-level (full-screen, outside the bottom nav) route whose system back
/// falls back to the Home tab when there's nothing underneath it — e.g. it
/// was opened from a shared link or via `context.go` — instead of closing
/// the app.
GoRoute _page(String path, Widget Function(GoRouterState state) builder) {
  return GoRoute(
    path: path,
    builder: (context, state) => _HomeFallback(child: builder(state)),
  );
}

class _HomeFallback extends StatelessWidget {
  const _HomeFallback({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ModalRoute.of registers a dependency, so this rebuilds whenever the
    // route's position in the stack changes.
    final isOnlyRoute = ModalRoute.of(context)?.isFirst ?? false;
    return PopScope(
      canPop: !isOnlyRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: child,
    );
  }
}

final GoRouter _appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    _page('/login', (_) => const Login()),
    _page('/register', (_) => const Register()),
    _page('/orders', (_) => const OrdersScreen()),
    _page('/wishlist', (_) => const WishlistPage()),
    _page('/addresses', (_) => const AddressBookScreen()),
    _page('/change-password', (_) => const ChangePasswordScreen()),
    _page('/data-privacy',
        (_) => const Scaffold(body: Center(child: Text('Data & Privacy')))),
    _page('/refund-policy',
        (_) => const Scaffold(body: Center(child: Text('Return & Refund Policy')))),
    _page('/shipping-policy',
        (_) => const Scaffold(body: Center(child: Text('Shipping Policy')))),
    _page('/store-locator',
        (_) => const Scaffold(body: Center(child: Text('Store Locator')))),
    _page('/track-order',
        (_) => const Scaffold(body: Center(child: Text('Track Your Order')))),
    // Matches the /products/:handle path of shared product links
    // (https://rookiesjeans.com/products/<handle>) so tapping one when the
    // app is installed opens this page instead of falling through to the
    // browser. Title is unknown until ProductDetailPage fetches the
    // product, so the handle is shown as a placeholder while loading.
    _page('/products/:handle', (state) => ProductDetailPage(
          handle: state.pathParameters['handle']!,
          title: state.pathParameters['handle']!,
        )),

    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // Branch order must match the visual icon order in
        // RookiesBottomNavBar (menu, search, home, profile, cart) so that
        // navigationShell.currentIndex highlights the correct icon.
        StatefulShellBranch(navigatorKey: _branchNavigatorKeys[0], routes: [
          GoRoute(
            path: '/category',
            builder: (context, state) => const ExploreCategoriesPage(),
          ),
        ]),
        StatefulShellBranch(navigatorKey: _branchNavigatorKeys[1], routes: [
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchTabPage(),
          ),
        ]),
        StatefulShellBranch(navigatorKey: _branchNavigatorKeys[2], routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
        ]),
        StatefulShellBranch(navigatorKey: _branchNavigatorKeys[3], routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ]),
        StatefulShellBranch(navigatorKey: _branchNavigatorKeys[4], routes: [
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
    // Pages pushed inside a tab are popped by their own branch navigator
    // before this is consulted. Once a non-Home tab is at its root, back
    // returns to the Home tab; only back on Home itself exits the app.
    final onHome = navigationShell.currentIndex == _homeBranchIndex;
    return PopScope(
      canPop: onHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(_homeBranchIndex);
      },
      child: _buildScaffold(),
    );
  }

  /// Always lands on the tapped tab's root page: pops anything pushed on
  /// top of it (product pages etc.) and resets it to its initial location.
  void _onTabTapped(int index) {
    _branchNavigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
    navigationShell.goBranch(index, initialLocation: true);
  }

  Widget _buildScaffold() {
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
        onTap: _onTabTapped,
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