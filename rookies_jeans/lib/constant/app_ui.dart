import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';

/// Available app-level theme choices exposed to the user (Profile ->
/// Theme Appearance).
enum AppThemeMode { light, dark, system }

/// Single source of truth for the user's chosen theme appearance.
/// Persists the choice across app restarts and drives both
/// `MaterialApp.themeMode` (in main.dart) and every `AppColors.*` value
/// below, so the whole app's constants stay in sync with the selection.
class ThemeService extends ChangeNotifier with WidgetsBindingObserver {
  static final ThemeService instance = ThemeService._();
  ThemeService._();

  static const _prefsKey = 'theme_mode';

  @override
  void didChangePlatformBrightness() {
    // Only matters when the user picked "System" — repaint so AppColors
    // picks up the OS's new brightness immediately, without needing a
    // restart or navigation.
    if (_mode == AppThemeMode.system) notifyListeners();
  }

  AppThemeMode _mode = AppThemeMode.system;
  AppThemeMode get mode => _mode;

  /// Resolves 'system' against the device's current platform brightness.
  bool get isDark {
    if (_mode == AppThemeMode.dark) return true;
    if (_mode == AppThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  String get label {
    switch (_mode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  /// Call once during app startup (e.g. in `main()`) before `runApp`.
  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    _mode = AppThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => AppThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

/// App-wide color constants. Every value below reads the current theme
/// selection from [ThemeService], so switching the theme in Profile ->
/// Theme Appearance changes these for every screen that references them.
class AppColors {
  AppColors._();

  static bool get _dark => ThemeService.instance.isDark;

  static Color get primary =>
      _dark ? Colors.white : const Color(ShopifyConstants.primaryColorHex);

  /// Color for text/icons drawn on TOP of a [primary]-colored surface
  /// (solid buttons, snackbars, badges). Always the inverse of [primary] so
  /// it stays readable in both themes — [primary] itself flips from
  /// near-black to white between light and dark, so content sitting on it
  /// must flip the other way.
  static Color get onPrimary => _dark ? const Color(0xFF121212) : Colors.white;
  static Color get accentOrange => const Color(ShopifyConstants.accentOrangeHex);
  static Color get bg => _dark ? const Color(0xFF121212) : const Color(ShopifyConstants.bgColorHex);
  static Color get card => _dark ? const Color(0xFF1E1E1E) : const Color(ShopifyConstants.cardColorHex);
  static Color get secondaryText =>
      _dark ? const Color(0xFFB0B0B0) : const Color(ShopifyConstants.secondaryTextHex);
  static Color get border => _dark ? const Color(0xFF2C2C2C) : const Color(ShopifyConstants.borderColorHex);

  /// Background for text fields / filled inputs. Distinct from [card] so
  /// inputs still read as "sunken" against a card in both themes.
  static Color get fieldFill => _dark ? const Color(0xFF2A2A2A) : const Color(0xfffafafa);

  /// Placeholder/hint text inside inputs and disabled-looking icons.
  static Color get hint => _dark ? const Color(0xFF8A8A8A) : const Color(0xff9a9a9a);

  static const Color danger  = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color muted   = Color(0xFF9A9A9A);
}

class AppFonts {
  AppFonts._();

  static const String heading    = ShopifyConstants.fontHeading;
  static const String subheading = ShopifyConstants.fontSubheading;
  static const String body       = ShopifyConstants.fontBody;
  static const String accent     = ShopifyConstants.fontAccent;
  static const String bold     = ShopifyConstants.fontBodyBold;
  static const String alteBold = ShopifyConstants.fontAlteBold;
  static const String number   = ShopifyConstants.fontNumber;
  static const String rupee    = ShopifyConstants.fontRupee;
}

class AppLayout {
  AppLayout._();

  static const double maxContentNarrow = 640;
  static const double maxContentMedium = 720;
}

class Responsive {
  const Responsive._(
    this.size,
    this.padding,
    this.baseW,
    this.baseH,
    this.minScale,
    this.maxScale,
  );

  final Size size;
  final EdgeInsets padding;
  final double baseW;
  final double baseH;
  final double minScale;
  final double maxScale;

  factory Responsive.of(
    BuildContext context, {
    double baseW = 390,
    double baseH = 844,
    double minScale = 0.85,
    double maxScale = 1.35,
  }) {
    final mq = MediaQuery.of(context);
    return Responsive._(
      mq.size,
      mq.padding,
      baseW,
      baseH,
      minScale,
      maxScale,
    );
  }

  double get width => size.width;
  double get height => size.height;

  double get safeWidth =>
   
      (width - padding.left - padding.right).clamp(0.0, width);

  bool get isTablet => width >= 600 && width < 1024;
  bool get isDesktop => width >= 1024;

  double get widthScale =>
      (width / baseW).clamp(minScale, maxScale).toDouble();
  double get heightScale =>
      (height / baseH).clamp(minScale, maxScale).toDouble();

  double s(double base) => base * widthScale;

  double sp(double base) => base * widthScale;

  double dp(double base) => base * widthScale;

  double vp(double base) => base * heightScale;
}

class AppToast {
  AppToast._();

  static String _toHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  static void show(String message, {bool isError = false}) {
    final bgColor = isError ? AppColors.danger : AppColors.primary;
    final textColor = isError ? Colors.white : AppColors.onPrimary;
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: bgColor,
      textColor: textColor,
      fontSize: 13,
      // Web renders its own toast markup using webBgColor rather than
      // `backgroundColor`, so it must track the same theme-aware color or
      // `textColor` above can end up unreadable against it (e.g. near-black
      // text on a hardcoded dark background in dark mode).
      webBgColor: _toHex(bgColor),
      webPosition: 'center',
      timeInSecForIosWeb: 2,
    );
  }
}
