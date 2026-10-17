import 'package:flutter/material.dart';
import 'helper/image_helper.dart';
import 'home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ImageHelper.init();
  runApp(const PriceScannerApp());
}

class PriceScannerApp extends StatelessWidget {
  const PriceScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B8A5A),
    );

    return MaterialApp(
      title: 'สแกนเช็คราคา',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
