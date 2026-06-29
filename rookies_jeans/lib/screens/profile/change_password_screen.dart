import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/services/shopify_auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const Color primary = Color(ShopifyConstants.primaryColorHex);
  static const Color secondaryText = Color(0xFF666666);

  static const String _fHead = ShopifyConstants.fontHeading;
  static const String _fBody = ShopifyConstants.fontBody;
  static const String _fBold = ShopifyConstants.fontBodyBold;

  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final result = await ShopifyAuthService.instance.recoverPassword(
      email: _emailController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: result.success ? primary : Colors.red,
        content: Text(
          result.message ?? '',
          style: const TextStyle(
            fontFamily: _fBody,
            color: Colors.white,
            fontSize: 13,
          ),
        ),
      ),
    );

    if (result.success) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: primary,
              ),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
            const Text(
              'RESET PASSWORD',
              style: TextStyle(
                fontSize: 34,
            height: 1,
            fontFamily: _fHead,
            color: Color(ShopifyConstants.primaryColorHex),
                // letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              const Text(
                "Enter your registered email address and we'll send you a password reset link.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _fBody,
                  fontSize: 13,
                  color: secondaryText,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 30),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                  fontFamily: _fBody,
                  fontSize: 14,
                  color: Colors.black,
                ),
                decoration: const InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(
                    fontFamily: _fBody,
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: primary,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter your email";
                  }

                  final emailRegex = RegExp(
                    r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$',
                  );

                  if (!emailRegex.hasMatch(value.trim())) {
                    return "Enter a valid email";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendResetLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "SEND RESET LINK",
                          style: TextStyle(
                            fontFamily: _fBold,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}