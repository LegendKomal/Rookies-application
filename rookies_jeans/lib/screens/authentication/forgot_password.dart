import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController emailController = TextEditingController();

  bool isLoading = false;
  bool emailSent = false;

  static const Color bgColor = Color(0xfff5f5f3);
  static const Color cardColor = Colors.white;
  static const Color primary = Color(0xff111111);
  static const Color secondaryText = Color(0xff6b6b6b);
  static const Color borderColor = Color(0xffdddddd);
  static const Color fieldFill = Color(0xfffafafa);

  // ---- Responsive helpers -------------------------------------------------
  // Everything scales off screen width so the form looks right on a 320px
  // phone, a 430px large phone, a 768px tablet and wider. 400px is baseline.
  double get _sf =>
      (MediaQuery.of(context).size.width / 400).clamp(0.85, 1.3).toDouble();

  /// Scale a size value responsively.
  double _s(double base) => base * _sf;

  /// Scale a fixed control height but keep it within comfortable touch bounds.
  double _h(double base) => (base * _sf).clamp(48.0, 64.0);

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: const Color(0xff9a9a9a),
        fontSize: _s(14.5),
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xff444444),
        size: _s(20),
      ),
      filled: true,
      fillColor: fieldFill,
      contentPadding:
          EdgeInsets.symmetric(vertical: _s(18), horizontal: _s(16)),
      border: const OutlineInputBorder(
        // borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: const OutlineInputBorder(
        // borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: const OutlineInputBorder(
        // borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primary, width: 1.2),
      ),
      errorBorder: const OutlineInputBorder(
        // borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.redAccent),
      ),
    );
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Future<void> _handleSendResetLink() async {
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();

    if (kDebugMode) {
      debugPrint('UI FORGOT PASSWORD CLICK -> email: $email');
    }

    if (email.isEmpty || !_isValidEmail(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await ShopifyAuthService.instance.recoverPassword(
        email: email,
      );

      if (!mounted) return;

      if (kDebugMode) {
        debugPrint(
            'UI FORGOT PASSWORD RESULT -> success: ${result.success}, message: ${result.message}');
      }

      if (result.success) {
        setState(() => emailSent = true);
      } else {
        _showMessage(
            result.message ?? 'Something went wrong. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Something went wrong: $e');
      if (kDebugMode) {
        debugPrint('UI FORGOT PASSWORD EXCEPTION -> $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primary,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Tighter side gutters on very small phones; a little more air elsewhere.
    final outerH = width < 360 ? 16.0 : _s(24);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: outerH, vertical: _s(24)),
            child: ConstrainedBox(
              // Cap width so the form stays a focused card on tablets/desktop.
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: EdgeInsets.all(_s(24)),
                decoration: BoxDecoration(
                  color: cardColor,
                  // borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: primary,
                            size: _s(24),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: _s(12)),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(_s(16)),
                            decoration: BoxDecoration(
                              color: fieldFill,
                              shape: BoxShape.circle,
                              border: Border.all(color: borderColor),
                            ),
                            child: Icon(
                              emailSent
                                  ? Icons.mark_email_read_outlined
                                  : Icons.lock_reset_rounded,
                              color: primary,
                              size: _s(28),
                            ),
                          ),
                          SizedBox(height: _s(18)),
                          Text(
                            emailSent ? "Check Your Email" : "Forgot Password?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _s(26),
                              fontWeight: FontWeight.w700,
                              color: primary,
                              // letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: _s(8)),
                          Text(
                            emailSent
                                ? "If an account exists for ${emailController.text.trim()}, we've sent a link to reset your password."
                                : "Enter the email linked to your account and we'll send you a link to reset your password.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _s(14.5),
                              color: secondaryText,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: _s(28)),
                    if (!emailSent) ...[
                      Text(
                        "Email",
                        style: TextStyle(
                          fontSize: _s(14),
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                      SizedBox(height: _s(8)),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(fontSize: _s(14.5)),
                        onFieldSubmitted: (_) => _handleSendResetLink(),
                        decoration: inputDecoration(
                          hintText: "Enter your email",
                          icon: Icons.mail_outline_rounded,
                        ),
                      ),
                      SizedBox(height: _s(22)),
                      SizedBox(
                        width: double.infinity,
                        height: _h(56),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _handleSendResetLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xff2d2d2d),
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                                // borderRadius: BorderRadius.circular(14),
                                ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  "Send Reset Link",
                                  style: TextStyle(
                                    fontSize: _s(16),
                                    fontWeight: FontWeight.w700,
                                    // letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: _h(56),
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => emailSent = false);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primary,
                            side: const BorderSide(color: borderColor),
                            shape: const RoundedRectangleBorder(
                                // borderRadius: BorderRadius.circular(14),
                                ),
                          ),
                          child: Text(
                            "Use a Different Email",
                            style: TextStyle(
                              fontSize: _s(15),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: _s(12)),
                      SizedBox(
                        width: double.infinity,
                        height: _h(56),
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                                // borderRadius: BorderRadius.circular(14),
                                ),
                          ),
                          child: Text(
                            "Back to Sign In",
                            style: TextStyle(
                              fontSize: _s(16),
                              fontWeight: FontWeight.w700,
                              // letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: _s(6)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}