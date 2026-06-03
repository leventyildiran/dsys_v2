import 'package:flutter/material.dart';

class AppTheme {
  static const Color sidebarColor = Color(0xFF1E1E2C);
  static const Color backgroundColor = Color(0xFFF5F6FA);
  static const Color primaryColor = Color(0xFF2C3E50);
  static const Color white = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        background: backgroundColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
    );
  }
}
