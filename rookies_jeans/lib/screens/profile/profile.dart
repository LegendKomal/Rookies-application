import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';

const double _kMaxContentW = 640;

double _s(BuildContext c, double base) =>
    Responsive.of(c, baseW: 375).s(base);

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  final String title;
  final String url;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  static Color get _primary => AppColors.primary;

  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError  = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _hasError  = false;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() {
            _isLoading = false;
            _hasError  = true;
          }),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: const Color(0xFFEEEEEE),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: _s(context, 18).clamp(16.0, 26.0),
              color: const Color(0xFF333333)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: ShopifyConstants.fontHeading,
            fontSize: _s(context, 17).clamp(15.0, 22.0),
            fontWeight: FontWeight.w500,
            color: const Color(0xFF111111),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (_hasError)
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(_s(context, 24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: _s(context, 48).clamp(40.0, 66.0),
                        color: const Color(0xFFBBBBBB)),
                    SizedBox(height: _s(context, 12)),
                    Text(
                      'Failed to load page',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: ShopifyConstants.fontBody,
                        fontSize: _s(context, 14).clamp(13.0, 18.0),
                        color: const Color(0xFF666666),
                      ),
                    ),
                    SizedBox(height: _s(context, 16)),
                    ElevatedButton(
                      onPressed: () => _controller.reload(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading && !_hasError)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: _primary,
            ),
        ],
      ),
    );
  }
}

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._();
  AuthService._();

  bool _isLoggedIn = false;
  String _firstName = '';
  String _lastName  = '';
  String _email     = '';

  bool   get isLoggedIn => _isLoggedIn;
  String get firstName  => _firstName;
  String get lastName   => _lastName;
  String get email      => _email;

  String get initials {
    final f = _firstName.isNotEmpty ? _firstName[0].toUpperCase() : '';
    final l = _lastName.isNotEmpty  ? _lastName[0].toUpperCase()  : '';
    return '$f$l';
  }

  Future<void> initialize() async {
    final loggedIn = await ShopifyAuthService.instance.isLoggedIn();
    if (!loggedIn) return;
    final customer = await ShopifyAuthService.instance.getCurrentCustomer();
    if (customer != null) {
      _firstName  = customer.firstName ?? '';
      _lastName   = customer.lastName  ?? '';
      _email      = customer.email     ?? '';
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  void signIn({
    required String firstName,
    required String lastName,
    required String email,
  }) {
    _firstName  = firstName;
    _lastName   = lastName;
    _email      = email;
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    await ShopifyAuthService.instance.logout();
    _firstName  = '';
    _lastName   = '';
    _email      = '';
    _isLoggedIn = false;
    notifyListeners();
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([AuthService.instance, ThemeService.instance]),
      builder: (context, _) {
        return AuthService.instance.isLoggedIn
            ? _LoggedInProfile()
            : _LoggedOutProfile();
      },
    );
  }
}

class _LoggedOutProfile extends StatelessWidget {
  const _LoggedOutProfile();

  static Color get _primary => AppColors.primary;
  static const _bg      = Color(0xFFF5F5F3);

  static const String _fHead = AppFonts.heading;
  static const String _fBody = AppFonts.body;
  static const String _fBold = AppFonts.bold;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final media   = MediaQuery.of(context);
          final screenH = media.size.height;
          final isWide  = constraints.maxWidth > _kMaxContentW;
          final halfH = (screenH * (isWide ? 0.5 : 0.66)).clamp(220.0, 560.0);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxContentW),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: halfH,
                      child: Image.asset(
                        'assets/welcome_model.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE0E0E0),
                          child: Icon(Icons.person,
                              size: _s(context, 96).clamp(72.0, 140.0),
                              color: const Color(0xFFBBBBBB)),
                        ),
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.fromLTRB(
                          _s(context, 24), _s(context, 28), _s(context, 24), _s(context, 28)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'WELCOME!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: _fHead,
                              color: _primary,
                              fontSize: _s(context, 26).clamp(22.0, 34.0),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: _s(context, 20)),
                          SizedBox(
                            height: _s(context, 50).clamp(46.0, 62.0),
                            child: ElevatedButton(
                              onPressed: () => context.push('/login'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  fontFamily: _fBold,
                                  fontSize: _s(context, 16).clamp(14.0, 20.0),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: _s(context, 14)),
                          Center(
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  fontFamily: _fBody,
                                  fontSize: _s(context, 13).clamp(12.0, 17.0),
                                  color: const Color(0xFF666666),
                                ),
                                children: [
                                  const TextSpan(text: "Don't have an account? "),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: GestureDetector(
                                      onTap: () => context.push('/register'),
                                      child: Text(
                                        'Create Account',
                                        style: TextStyle(
                                          fontFamily: _fBold,
                                          fontSize: _s(context, 13).clamp(12.0, 17.0),
                                          color: _primary,
                                          decoration: TextDecoration.underline,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: _s(context, 12)),
                    const _MoreSection(showSignOut: false),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoggedInProfile extends StatelessWidget {
  const _LoggedInProfile();

  static Color get _primary => AppColors.primary;
  static const _bg      = Color(0xFFFFFFFF);

  static const String _fHead = AppFonts.heading;
  static const String _fBold = AppFonts.bold;

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxContentW),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.fromLTRB(
                        _s(context, 24), _s(context, 40), _s(context, 24), _s(context, 32)),
                    child: Column(
                      children: [
                        Container(
                          width: _s(context, 72).clamp(64.0, 96.0),
                          height: _s(context, 72).clamp(64.0, 96.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F0),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFE0E0E0), width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            auth.initials,
                            style: TextStyle(
                              fontFamily: _fBold,
                              fontSize: _s(context, 24).clamp(20.0, 32.0),
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ),
                        SizedBox(height: _s(context, 14)),
                        Text(
                          auth.firstName.isNotEmpty
                              ? 'Hey, ${auth.firstName}!'
                              : 'Hey!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: _fHead,
                            fontSize: _s(context, 22).clamp(18.0, 30.0),
                            fontWeight: FontWeight.w500,
                            color: _primary,
                          ),
                        ),
                        SizedBox(height: _s(context, 28)),
                        Row(
                          children: const [
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.inventory_2_outlined,
                                label: 'Order\nHistory',
                                color: Color(0xFFE8A020),
                                route: '/orders',
                              ),
                            ),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.menu_book_outlined,
                                label: 'Address\nBook',
                                color: Color(0xFF4285F4),
                                route: '/addresses',
                              ),
                            ),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.chat_bubble_outline_rounded,
                                label: 'Change\nPassword',
                                color: Color(0xFF888888),
                                route: '/change-password',
                              ),
                            ),
                            Expanded(
                              child: _QuickAction(
                                icon: Icons.favorite_border_rounded,
                                label: 'Your\nFavourites',
                                color: Color(0xFFD32F2F),
                                route: '/wishlist',
                                useGo: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: _s(context, 12)),
                  const _MoreSection(showSignOut: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.showSignOut});
  final bool showSignOut;

  static const String _fHead = AppFonts.heading;

  void _openWebView(BuildContext context, {
    required String title,
    required String url,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebViewScreen(title: title, url: url),
      ),
    );
  }

  void _showThemeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: ThemeService.instance,
          builder: (context, _) {
            final current = ThemeService.instance.mode;

            Widget option(AppThemeMode mode, String label, IconData icon) {
              final selected = current == mode;
              return ListTile(
                leading: Icon(
                  icon,
                  color: selected ? AppColors.primary : const Color(0xFF888888),
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: _s(context, 15).clamp(13.0, 18.0),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? AppColors.primary : const Color(0xFF333333),
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  ThemeService.instance.setMode(mode);
                  Navigator.of(sheetContext).pop();
                },
              );
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: _s(context, 12)),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDDDDD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        _s(context, 20), _s(context, 16), _s(context, 20), _s(context, 4)),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Theme Appearance',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: _s(context, 18).clamp(16.0, 24.0),
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF111111),
                        ),
                      ),
                    ),
                  ),
                  option(AppThemeMode.light, 'Light', Icons.light_mode_outlined),
                  option(AppThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
                  option(AppThemeMode.system, 'System', Icons.settings_suggest_outlined),
                  SizedBox(height: _s(context, 8)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  _s(context, 20), _s(context, 20), _s(context, 20), _s(context, 6)),
              child: Text(
                'More',
                style: TextStyle(
                  fontFamily: _fHead,
                  fontSize: _s(context, 22).clamp(18.0, 30.0),
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF111111),
                ),
              ),
            ),
            _MoreTile(
              label: 'Theme Appearance',
              trailingText: ThemeService.instance.label,
              onTap: () => _showThemeSheet(context),
            ),
            _MoreTile(
              label: 'Data & Privacy',
              onTap: () => _openWebView(
                context,
                title: 'Data & Privacy',
                url: 'https://rookiesjeans.com/policies/privacy-policy',
              ),
            ),
            _MoreTile(
              label: 'Return & Refund Policy',
              onTap: () => _openWebView(
                context,
                title: 'Return & Refund Policy',
                url: 'https://rookiesjeans.com/policies/refund-policy',
              ),
            ),
            _MoreTile(
              label: 'Shipping Policy',
              onTap: () => _openWebView(
                context,
                title: 'Shipping Policy',
                url: 'https://rookiesjeans.com/policies/shipping-policy',
              ),
            ),
            _MoreTile(
              label: 'Store Locator',
              onTap: () => _openWebView(
                context,
                title: 'Store Locator',
                url: 'https://rookiesjeans.com/pages/store-locator',
              ),
            ),
            _MoreTile(
              label: 'Track Your Order',
              onTap: () => _openWebView(
                context,
                title: 'Track Your Order',
                url: 'https://rookiesjeans.shiprocket.co/',
              ),
            ),
            if (showSignOut)
              _MoreTile(
                label: 'Sign Out',
                icon: Icons.logout_rounded,
                onTap: () async {
                  await AuthService.instance.signOut();
                  if (context.mounted) context.go('/home');
                },
              ),
            SizedBox(height: _s(context, 8)),
          ],
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.label,
    required this.onTap,
    this.icon,
    this.trailingText,
  });
  final String       label;
  final VoidCallback onTap;
  final IconData?    icon;
  final String?      trailingText;

  static const String _fBody = AppFonts.body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: _s(context, 20), vertical: _s(context, 15)),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: _s(context, 18).clamp(16.0, 24.0),
                      color: const Color(0xFF555555)),
                  SizedBox(width: _s(context, 10)),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: _fBody,
                      fontSize: _s(context, 14).clamp(13.0, 18.0),
                      color: const Color(0xFF333333),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (trailingText != null) ...[
                  Text(
                    trailingText!,
                    style: TextStyle(
                      fontFamily: _fBody,
                      fontSize: _s(context, 13).clamp(12.0, 16.0),
                      color: const Color(0xFF999999),
                    ),
                  ),
                  SizedBox(width: _s(context, 6)),
                ],
                Icon(Icons.chevron_right_rounded,
                    size: _s(context, 18).clamp(16.0, 24.0),
                    color: const Color(0xFFBBBBBB)),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
    this.useGo = false,
  });

  final IconData icon;
  final String   label;
  final Color    color;
  final String   route;
  final bool     useGo;

  static const String _fBody = AppFonts.body;

  @override
  Widget build(BuildContext context) {
    final circle = _s(context, 56).clamp(48.0, 72.0);
    return GestureDetector(
      onTap: () => useGo ? context.go(route) : context.push(route),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _s(context, 2)),
        child: Column(
          children: [
            Container(
              width: circle,
              height: circle,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: color, size: _s(context, 24).clamp(20.0, 32.0)),
            ),
            SizedBox(height: _s(context, 8)),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle( 
                fontFamily: _fBody,
                fontSize: _s(context, 11).clamp(10.0, 14.0),
                color: const Color(0xFF555555),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}