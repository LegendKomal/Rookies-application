import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';

class AppColors {
  AppColors._();

  static const Color primary       = Color(ShopifyConstants.primaryColorHex);
  static const Color accentOrange  = Color(ShopifyConstants.accentOrangeHex);
  static const Color bg            = Color(ShopifyConstants.bgColorHex);
  static const Color card          = Color(ShopifyConstants.cardColorHex);
  static const Color secondaryText = Color(ShopifyConstants.secondaryTextHex);
  static const Color border        = Color(ShopifyConstants.borderColorHex);

  static const Color danger  = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color muted   = Color(0xFF9A9A9A);
}

class AppFonts {
  AppFonts._();

  static const String heading  = ShopifyConstants.fontHeading;
  static const String body     = ShopifyConstants.fontBody;
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

  static void show(String message, {bool isError = false}) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? AppColors.danger : AppColors.primary,
      textColor: Colors.white,
      fontSize: 13,
      webBgColor: isError ? '#D32F2F' : '#1A1A1A',
      webPosition: 'center',
      timeInSecForIosWeb: 2,
    );
  }
}
