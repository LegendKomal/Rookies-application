import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/screens/profile/profile.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';

class Register extends StatefulWidget {
  const Register({super.key, this.isCheckoutFlow = false});

  final bool isCheckoutFlow;

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final TextEditingController firstNameController       = TextEditingController();
  final TextEditingController lastNameController        = TextEditingController();
  final TextEditingController emailController           = TextEditingController();
  final TextEditingController phoneController           = TextEditingController();
  final TextEditingController passwordController        = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isPasswordHidden        = true;
  bool isConfirmPasswordHidden = true;
  bool acceptsMarketing        = true;
  bool isLoading               = false;

  static const Color bgColor       = Color(0xfff5f5f3);
  static const Color cardColor     = Colors.white;
  static const Color primary       = AppColors.primary;
  static const Color secondaryText = AppColors.secondaryText;
  static const Color borderColor   = AppColors.border;
  static const Color fieldFill     = Color(0xfffafafa);

  static const String _fHead = AppFonts.heading;
  static const String _fBody = AppFonts.body;
  static const String _fBold = AppFonts.bold;

  double _s(double base) =>
      Responsive.of(context, baseW: 400, maxScale: 1.3).s(base);

  double _h(double base) => _s(base).clamp(48.0, 64.0);

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
        fontFamily: _fBody,
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
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: primary, width: 1.2),
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: TextStyle(
          fontFamily: _fBold,
          fontSize: _s(14),
          fontWeight: FontWeight.w600,
          color: primary,
        ),
      );

  bool _isValidEmail(String email) =>
      RegExp(r'^[\w\.\-+]+@[\w\-]+(\.[\w\-]+)+$').hasMatch(email);

  String? _validateInputs() {
    final firstName = firstNameController.text.trim();
    final email     = emailController.text.trim();
    final password  = passwordController.text;
    final confirm   = confirmPasswordController.text;
    final phone     = phoneController.text.trim();

    if (firstName.isEmpty) return 'Please enter your first name.';
    if (email.isEmpty) return 'Please enter your email.';
    if (!_isValidEmail(email)) return 'Please enter a valid email address.';
    if (password.isEmpty) return 'Please enter a password.';
    if (password.length < 8) {
      // Shopify requires passwords to be at least 8 characters (max 40).
      return 'Password must be at least 8 characters.';
    }
    if (confirm != password) return 'Passwords do not match.';
    if (phone.isNotEmpty && !RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone)) {
      // Shopify expects E.164 format, e.g. +919876543210
      return 'Enter a valid phone number (e.g. +919876543210).';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    final error = _validateInputs();
    if (error != null) {
      _showMessage(error);
      return;
    }

    final firstName = firstNameController.text.trim();
    final lastName  = lastNameController.text.trim();
    final email     = emailController.text.trim();
    final phone     = phoneController.text.trim();
    final password  = passwordController.text;

    if (kDebugMode) debugPrint('UI REGISTER CLICK -> email: $email');

    setState(() => isLoading = true);

    try {
      final result = await ShopifyAuthService.instance.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        phone: phone.isEmpty ? null : phone,
        acceptsMarketing: acceptsMarketing,
      );

      if (!mounted) return;

      if (!result.success) {
        _showMessage(result.message ?? 'Registration failed');
        if (kDebugMode) debugPrint('UI REGISTER FAILED -> ${result.message}');
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
            : 'Account created successfully',
      );

      if (kDebugMode) {
        debugPrint('UI REGISTER SUCCESS -> ${result.customer?.toJson()}');
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (widget.isCheckoutFlow) {
        Navigator.of(context).pop(true);
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Something went wrong: $e');
      if (kDebugMode) debugPrint('UI REGISTER EXCEPTION -> $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primary,
        behavior: SnackBarBehavior.floating,
        content: Text(
          message,
          style: TextStyle(fontFamily: _fBody, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width  = MediaQuery.of(context).size.width;
    final outerH = width < 360 ? 16.0 : _s(24);

    // On wider screens (tablet / landscape), show first & last name side by side.
    final bool twoColumnName = width >= 400;

    final firstNameField = TextFormField(
      controller: firstNameController,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      style: TextStyle(fontFamily: _fBody, fontSize: _s(14.5)),
      decoration: inputDecoration(
        hintText: "First name",
        icon: Icons.person_outline_rounded,
      ),
    );

    final lastNameField = TextFormField(
      controller: lastNameController,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      style: TextStyle(fontFamily: _fBody, fontSize: _s(14.5)),
      decoration: inputDecoration(
        hintText: "Last name",
        icon: Icons.person_outline_rounded,
      ),
    );

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
                            "Create Account",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: _fHead,
                              fontSize: _s(30),
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                          SizedBox(height: _s(8)),
                          Text(
                            "Join ROOKIES to start shopping",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: _fBody,
                              fontSize: _s(15),
                              color: secondaryText,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: _s(32)),

                    // ---------- Name ----------
                    _fieldLabel("Name"),
                    SizedBox(height: _s(8)),
                    if (twoColumnName)
                      Row(
                        children: [
                          Expanded(child: firstNameField),
                          SizedBox(width: _s(12)),
                          Expanded(child: lastNameField),
                        ],
                      )
                    else ...[
                      firstNameField,
                      SizedBox(height: _s(12)),
                      lastNameField,
                    ],
                    SizedBox(height: _s(18)),

                    // ---------- Email ----------
                    _fieldLabel("Email"),
                    SizedBox(height: _s(8)),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: TextStyle(fontFamily: _fBody, fontSize: _s(14.5)),
                      decoration: inputDecoration(
                        hintText: "Enter your email",
                        icon: Icons.mail_outline_rounded,
                      ),
                    ),
                    SizedBox(height: _s(18)),

                    // ---------- Phone (optional) ----------
                    _fieldLabel("Phone (optional)"),
                    SizedBox(height: _s(8)),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(fontFamily: _fBody, fontSize: _s(14.5)),
                      decoration: inputDecoration(
                        hintText: "+91 phone number",
                        icon: Icons.phone_outlined,
                      ),
                    ),
                    SizedBox(height: _s(18)),

                    // ---------- Password ----------
                    _fieldLabel("Password"),
                    SizedBox(height: _s(8)),
                    TextFormField(
                      controller: passwordController,
                      obscureText: isPasswordHidden,
                      style: TextStyle(fontFamily: _fBody, fontSize: _s(14.5)),
                      decoration: inputDecoration(
                        hintText: "Minimum 8 characters",
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
                    SizedBox(height: _s(18)),

                    // ---------- Confirm Password ----------
                    _fieldLabel("Confirm Password"),
                    SizedBox(height: _s(8)),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: isConfirmPasswordHidden,
                      style: TextStyle(fontFamily: _fBody, fontSize: _s(14.5)),
                      decoration: inputDecoration(
                        hintText: "Re-enter your password",
                        icon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() =>
                              isConfirmPasswordHidden =
                                  !isConfirmPasswordHidden),
                          icon: Icon(
                            isConfirmPasswordHidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xff555555),
                            size: _s(22),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: _s(14)),

                    // ---------- Marketing opt-in ----------
                    InkWell(
                      onTap: () => setState(
                          () => acceptsMarketing = !acceptsMarketing),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: _s(22),
                            height: _s(22),
                            child: Checkbox(
                              value: acceptsMarketing,
                              activeColor: primary,
                              side: const BorderSide(color: borderColor),
                              onChanged: (v) => setState(
                                  () => acceptsMarketing = v ?? false),
                            ),
                          ),
                          SizedBox(width: _s(10)),
                          Expanded(
                            child: Text(
                              "Keep me updated on new drops and offers",
                              style: TextStyle(
                                fontFamily: _fBody,
                                fontSize: _s(13),
                                color: secondaryText,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: _s(20)),

                    // ---------- Submit ----------
                    SizedBox(
                      width: double.infinity,
                      height: _h(56),
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xff2d2d2d),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: Colors.white),
                              )
                            : Text(
                                "Create Account",
                                style: TextStyle(
                                  fontFamily: _fBold,
                                  fontSize: _s(16),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: _s(22)),

                    // ---------- Already have account ----------
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: TextStyle(
                              fontFamily: _fBody,
                              color: secondaryText,
                              fontSize: _s(14),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.push('/login');
                              }
                            },
                            child: Text(
                              "Sign In",
                              style: TextStyle(
                                fontFamily: _fBold,
                                color: primary,
                                fontSize: _s(14),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
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