import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rookies_jeans/screens/Dashboard/home_screen.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordHidden = true;
  bool isLoading = false;

  static const Color bgColor = Color(0xfff5f5f3);
  static const Color cardColor = Colors.white;
  static const Color primary = Color(0xff111111);
  static const Color secondaryText = Color(0xff6b6b6b);
  static const Color borderColor = Color(0xffdddddd);
  static const Color fieldFill = Color(0xfffafafa);

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
      hintStyle: const TextStyle(
        color: Color(0xff9a9a9a),
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xff444444),
        size: 20,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (kDebugMode) {
      debugPrint('UI LOGIN CLICK -> email: $email');
    }

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter email and password.');
      if (kDebugMode) {
        debugPrint('UI LOGIN VALIDATION FAILED -> empty email/password');
      }
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
        _showMessage(
  result.customer != null
      ? 'Welcome ${result.customer!.fullName}'
      : 'Login successful',
);
        if (kDebugMode) {
          debugPrint('UI LOGIN FAILED -> ${result.message}');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('UI LOGIN SUCCESS -> ${result.customer?.toJson()}');
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => const HomeScreen(),
  ),
);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Something went wrong: $e');
      if (kDebugMode) {
        debugPrint('UI LOGIN EXCEPTION -> $e');
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
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
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
                    const SizedBox(height: 4),
                    Center(
                      child: Column(
                        children: const [
                          Text(
                            "Welcome Back",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: primary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Sign in to continue to ROOKIES",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: secondaryText,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "Email",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: inputDecoration(
                        hintText: "Enter your email",
                        icon: Icons.mail_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      "Password",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: passwordController,
                      obscureText: isPasswordHidden,
                      decoration: inputDecoration(
                        hintText: "Enter your password",
                        icon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              isPasswordHidden = !isPasswordHidden;
                            });
                          },
                          icon: Icon(
                            isPasswordHidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xff555555),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          foregroundColor: primary,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xff2d2d2d),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
                            : const Text(
                                "Sign In",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "New to ROOKIES? ",
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            "Create Account",
                            style: TextStyle(
                              color: primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
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