import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';

// ─────────────────────────────────────────────
//  WebView Screen
// ─────────────────────────────────────────────

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
  static const _primary = Color(ShopifyConstants.primaryColorHex);

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
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF333333)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontFamily: ShopifyConstants.fontHeading,
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111111),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ── Error state ──────────────────────────────
          if (_hasError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 48, color: Color(0xFFBBBBBB)),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to load page',
                    style: TextStyle(
                      fontFamily: ShopifyConstants.fontBody,
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _controller.reload(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        // borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )

          // ── WebView ──────────────────────────────────
          else
            WebViewWidget(controller: _controller),

          // ── Loading indicator ────────────────────────
          if (_isLoading && !_hasError)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: _primary,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  AuthService  (unchanged)
// ─────────────────────────────────────────────

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

// ─────────────────────────────────────────────
//  ProfileScreen  (unchanged)
// ─────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        return AuthService.instance.isLoggedIn
            ? const _LoggedInProfile()
            : const _LoggedOutProfile();
      },
    );
  }
}

// ─────────────────────────────────────────────
//  _LoggedOutProfile  (unchanged)
// ─────────────────────────────────────────────

class _LoggedOutProfile extends StatelessWidget {
  const _LoggedOutProfile();

  static const _primary = Color(ShopifyConstants.primaryColorHex);
  static const _bg      = Color(0xFFF5F5F3);

  static const String _fHead = ShopifyConstants.fontHeading;
  static const String _fBody = ShopifyConstants.fontBody;
  static const String _fBold = ShopifyConstants.fontBodyBold;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenH = MediaQuery.of(context).size.height;
          final halfH   = screenH * 0.66;

          return SingleChildScrollView(
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
                      child: const Icon(Icons.person,
                          size: 96, color: Color(0xFFBBBBBB)),
                    ),
                  ),
                ),

                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'WELCOME!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: _fHead,
                          color: _primary,
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => context.push('/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            // shape: RoundedRectangleBorder(
                            //   borderRadius: BorderRadius.circular(8),
                            // ),
                          ),
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              fontFamily: _fBold,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: _fBody,
                              fontSize: 13,
                              color: const Color(0xFF666666),
                            ),
                            children: [
                              const TextSpan(text: "Don't have an account? "),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => context.push('/register'),
                                  child: Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontFamily: _fBold,
                                      fontSize: 13,
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

                const SizedBox(height: 12),
                const _MoreSection(showSignOut: false),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _LoggedInProfile  (unchanged)
// ─────────────────────────────────────────────

class _LoggedInProfile extends StatelessWidget {
  const _LoggedInProfile();

  static const _primary = Color(ShopifyConstants.primaryColorHex);
  static const _bg      = Color(0xFFF5F5F3);

  static const String _fHead = ShopifyConstants.fontHeading;
  static const String _fBold = ShopifyConstants.fontBodyBold;

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFE0E0E0), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        auth.initials,
                        style: const TextStyle(
                          fontFamily: _fBold,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      auth.firstName.isNotEmpty
                          ? 'Hey, ${auth.firstName}!'
                          : 'Hey!',
                      style: const TextStyle(
                        fontFamily: _fHead,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _QuickAction(
                          icon: Icons.inventory_2_outlined,
                          label: 'Order\nHistory',
                          color: const Color(0xFFE8A020),
                          onTap: () => context.push('/orders'),
                        ),
                        _QuickAction(
                          icon: Icons.menu_book_outlined,
                          label: 'Address\nBook',
                          color: const Color(0xFF4285F4),
                          onTap: () => context.push('/addresses'),
                        ),
                        _QuickAction(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Change\nPassword',
                          color: const Color(0xFF888888),
                          onTap: () => context.push('/change-password'),
                        ),
                        _QuickAction(
                          icon: Icons.favorite_border_rounded,
                          label: 'Your\nFavourites',
                          color: const Color(0xFFD32F2F),
                          onTap: () => context.go('/wishlist'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const _MoreSection(showSignOut: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.showSignOut});
  final bool showSignOut;

  static const String _fHead = ShopifyConstants.fontHeading;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
            child: Text(
              'More',
              style: TextStyle(
                fontFamily: _fHead,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF111111),
              ),
            ),
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

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.label, required this.onTap, this.icon});

  final String       label;
  final VoidCallback onTap;
  final IconData?    icon;

  static const String _fBody = ShopifyConstants.fontBody;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: const Color(0xFF555555)),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: _fBody,
                    fontSize: 14,
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: Color(0xFFBBBBBB)),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  _QuickAction  (unchanged)
// ─────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  static const String _fBody = ShopifyConstants.fontBody;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _fBody,
              fontSize: 11,
              color: Color(0xFF555555),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}