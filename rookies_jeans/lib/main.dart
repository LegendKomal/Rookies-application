import 'package:flutter/material.dart';
import 'package:rookies_jeans/screens/splashscreen/splashscreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xfff5f5f3);
    const primary = Color(0xff111111);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rookies',
      theme: ThemeData(
        useMaterial3: true,
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
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: primary,
        ),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        dividerColor: const Color(0xffe7e7e7),
      ),
      home: const SplashScreen(),
    );
  }
}