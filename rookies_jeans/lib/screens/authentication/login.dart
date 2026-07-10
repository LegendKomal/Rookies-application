import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/screens/authentication/forgot_password.dart';
import 'package:rookies_jeans/screens/profile/profile.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';

class Login extends StatefulWidget {
  const Login({super.key, this.isCheckoutFlow = false});

  final bool isCheckoutFlow;

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordHidden = true;
  bool isLoading        = false;

  static const Color bgColor      = Color(0xfff5f5f3);
  static const Color cardColor    = Colors.white;
  static const Color primary      = AppColors.primary;
  static const Color secondaryText = AppColors.secondaryText;
  static const Color borderColor  = AppColors.border;
  static const Color fieldFill    = Color(0xfffafafa);

  double _s(double base) =>
      Responsive.of(context, baseW: 400, maxScale: 1.3).s(base);

  double _h(double base) => _s(base).clamp(48.0, 64.0);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  InputDecoration inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: const Color(0xff9a9a9a),
        fontSize: _s(14.5),
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(icon, color: const Color(0xff444444), size: _s(20)),
      suffixIcon: suffixIcon,
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

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    final email    = emailController.text.trim();
    final password = passwordController.text.trim();

    if (kDebugMode) debugPrint('UI LOGIN CLICK -> email: $email');

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter email and password.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await ShopifyAuthService.instance.login(
        email: email,
        password: password,
      );

      if (!mounted) return;

      if (!result.success) {
        _showMessage(result.message ?? 'Login failed');
        if (kDebugMode) debugPrint('UI LOGIN FAILED -> ${result.message}');
        return;
      }

      if (result.customer != null) {
        AuthService.instance.signIn(
          firstName: result.customer!.firstName ?? '',
          lastName:  result.customer!.lastName  ?? '',
          email:     result.customer!.email     ?? '',
        );
      }
      _showMessage(
        result.customer != null
            ? 'Welcome ${result.customer!.fullName}'
            : 'Login successful',
      );

      if (kDebugMode) debugPrint('UI LOGIN SUCCESS -> ${result.customer?.toJson()}');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (widget.isCheckoutFlow) {
        Navigator.of(context).pop(true);
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Something went wrong: $e');
      if (kDebugMode) debugPrint('UI LOGIN EXCEPTION -> $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primary,
        behavior: SnackBarBehavior.floating,
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  void _handleForgotPassword() {
    if (kDebugMode) debugPrint('UI FORGOT PASSWORD TAP');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPassword()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final outerH = width < 360 ? 16.0 : _s(24);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: outerH, vertical: _s(24)),
            child: ConstrainedBox(
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
                    SizedBox(height: _s(4)),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            "Welcome Back",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _s(30),
                              fontWeight: FontWeight.w700,
                              color: primary,
                              // letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: _s(8)),
                          Text(
                            "Sign in to continue to ROOKIES",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _s(15),
                              color: secondaryText,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: _s(32)),
                    Text("Email",
                        style: TextStyle(
                            fontSize: _s(14),
                            fontWeight: FontWeight.w600,
                            color: primary)),
                    SizedBox(height: _s(8)),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(fontSize: _s(14.5)),
                      decoration: inputDecoration(
                        hintText: "Enter your email",
                        icon: Icons.mail_outline_rounded,
                      ),
                    ),
                    SizedBox(height: _s(18)),
                    Text("Password",
                        style: TextStyle(
                            fontSize: _s(14),
                            fontWeight: FontWeight.w600,
                            color: primary)),
                    SizedBox(height: _s(8)),
                    TextFormField(
                      controller: passwordController,
                      obscureText: isPasswordHidden,
                      style: TextStyle(fontSize: _s(14.5)),
                      decoration: inputDecoration(
                        hintText: "Enter your password",
                        icon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                              () => isPasswordHidden = !isPasswordHidden),
                          icon: Icon(
                            isPasswordHidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xff555555),
                            size: _s(22),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: _s(14)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: primary,
                          padding: EdgeInsets.zero,
                        ),
                        child: Text("Forgot Password?",
                            style: TextStyle(
                                fontSize: _s(13.5),
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    SizedBox(height: _s(18)),
                    SizedBox(
                      width: double.infinity,
                      height: _h(56),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xff2d2d2d),
                          elevation: 0,
                          // shape: RoundedRectangleBorder(
                          //     borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: Colors.white),
                              )
                            : Text("Sign In",
                                style: TextStyle(
                                    fontSize: _s(16),
                                    fontWeight: FontWeight.w700,
                                    // letterSpacing: 0.2
                                    )),
                      ),
                    ),
                    SizedBox(height: _s(22)),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text("New to ROOKIES? ",
                            style: TextStyle(
                                color: secondaryText, fontSize: _s(14))),
                        GestureDetector(
                          onTap: () => context.push('/register'),
                          child: Text("Create Account",
                              style: TextStyle(
                                  color: primary,
                                  fontSize: _s(14),
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
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