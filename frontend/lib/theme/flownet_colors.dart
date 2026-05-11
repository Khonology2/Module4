import 'package:flutter/material.dart';

class FlownetColors {
  // Primary Colors
  static const Color electricBlue = Color(0xFF00A8E8);
  static const Color deepBlue = Color(0xFF0077B6);
  
  // Secondary Colors
  static const Color crimsonRed = Color(0xFFD90429);
  static const Color emeraldGreen = Color(0xFF2EC4B6);
  
  // Neutrals
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF8F9FA);
  static const Color mediumGray = Color(0xFF6C757D);
  static const Color charcoalBlack = Color(0xFF212529);
  
  // Status Colors
  static const Color successGreen = Color(0xFF28A745);
  static const Color warningYellow = Color(0xFFFFC107);
  static const Color errorRed = Color(0xFFDC3545);
  static const Color infoBlue = Color(0xFF17A2B8);
  
  // Background Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color cardBackground = Color(0xFF1E1E1E);
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textDisabled = Color(0xFF6C757D);
  
  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF00A8E8),
    Color(0xFF0077B6),
  ];
  
  // Utility method to parse color from hex string
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

// Extension to add color methods to Color class
extension ColorExtension on Color {
  Color withValues({int? red, int? green, int? blue, double? alpha}) {
    return Color.fromARGB(
      alpha != null ? (alpha * 255).round() & 0xff : (a * 255).round() & 0xff,
      red ?? (r * 255).round(),
      green ?? (g * 255).round(),
      blue ?? (b * 255).round(),
    );
  }
}
