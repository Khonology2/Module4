import 'package:flutter/material.dart';

class FlownetColors {
  // Primary Colors
  static const Color primary = Color(0xFFC10D00);  // Main brand red
  static const Color background = Color(0xFF121212);  // Dark background
  static const Color surface = Color(0xFF1E1E1E);     // Surface color
  static const Color onSurface = Color(0xFFFFFFFF);   // Text on surface
  
  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textTertiary = Color(0xFF8E8E93);
  
  // Accent Colors
  static const Color accent = Color(0xFFFF3B30);
  static const Color blue = Color(0xFF0A84FF);
  static const Color green = Color(0xFF34C759);
  static const Color yellow = Color(0xFFFFCC00);
  
  // Status Colors
  static const Color success = Color(0xFF34C759);
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFF9500);
  static const Color info = Color(0xFF007AFF);
  
  // Surface Colors
  static const Color surfaceLight = Color(0xFF2C2C2E);
  static const Color surfaceHighlight = Color(0xFF3A3A3C);
  
  // Additional Colors from the codebase
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color charcoalBlack = Color(0xFF1A1A1A);
  static const Color graphiteGray = Color(0xFF666666);
  static const Color coolGray = Color(0xFF8E8E93);
  static const Color slate = Color(0xFF64748B); // Added missing slate color
  static const Color electricBlue = Color(0xFF007AFF);
  static const Color emeraldGreen = Color(0xFF34C759);
  static const Color amberOrange = Color(0xFFFF9500);
  static const Color crimsonRed = Color(0xFFC10D00);
  static const Color purple = Color(0xFF9C27B0);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF3B30), Color(0xFFC10D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Aliases for backward compatibility
  static const Color onBackground = textPrimary;
  static const Color onError = pureWhite;
  static const Color onPrimary = pureWhite;
  static const Color onSecondary = pureWhite;
}

class FlownetTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: FlownetColors.background,
      
      // Color Scheme
      colorScheme: ColorScheme.dark(
        primary: FlownetColors.primary,
        onPrimary: FlownetColors.onPrimary,
        primaryContainer: Color.lerp(FlownetColors.primary, FlownetColors.background, 0.8)!,
        onPrimaryContainer: FlownetColors.primary,
        secondary: FlownetColors.accent,
        onSecondary: FlownetColors.onSecondary,
        secondaryContainer: Color.lerp(FlownetColors.accent, FlownetColors.background, 0.8)!,
        onSecondaryContainer: FlownetColors.accent,
        error: FlownetColors.error,
        onError: FlownetColors.onError,
        surface: FlownetColors.surface,
        onSurface: FlownetColors.onSurface,
        surfaceContainerHighest: FlownetColors.surfaceLight,
        onSurfaceVariant: FlownetColors.textSecondary,
        outline: FlownetColors.textTertiary,
        
        surfaceTint: FlownetColors.primary,
      ),
      // Translucent AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: FlownetColors.pureWhite),
        titleTextStyle: TextStyle(
          color: FlownetColors.pureWhite,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          fontFamily: 'Poppins',
        ),
      ),
      // Translucent cards
      cardTheme: CardThemeData(
        color: Colors.white.withAlpha((0.08 * 255).round()),
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withAlpha((0.12 * 255).round())),
        ),
        margin: const EdgeInsets.all(8),
      ),
      // Dialogs (AlertDialog, SimpleDialog)
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xF21E1E1E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withAlpha((0.35 * 255).round())),
        ),
      ),
      // Bottom sheets
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xF21E1E1E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withAlpha((0.18 * 255).round()),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha((0.40 * 255).round())),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withAlpha((0.40 * 255).round())),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlownetColors.primary, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.white.withAlpha((0.80 * 255).round())),
        hintStyle: TextStyle(color: Colors.white.withAlpha((0.65 * 255).round())),
        errorStyle: const TextStyle(color: FlownetColors.error),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      // Popup menus
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white.withAlpha((0.10 * 255).round()),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withAlpha((0.12 * 255).round())),
        ),
      ),
      // List tiles subtle background when needed
      listTileTheme: ListTileThemeData(
        tileColor: Colors.white.withAlpha((0.05 * 255).round()),
        iconColor: FlownetColors.pureWhite,
        textColor: FlownetColors.pureWhite,
      ),
      
      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.bold,
          color: FlownetColors.textPrimary,
          letterSpacing: 1.5,
          fontFamily: 'Poppins',
        ),
        displayMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: FlownetColors.textPrimary,
          fontFamily: 'Poppins',
        ),
        displaySmall: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: FlownetColors.textPrimary,
          fontFamily: 'Poppins',
        ),
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: FlownetColors.textPrimary,
          fontFamily: 'Poppins',
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: FlownetColors.textPrimary,
          fontFamily: 'Poppins',
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: FlownetColors.textPrimary,
          fontFamily: 'Poppins',
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: FlownetColors.textPrimary,
          fontFamily: 'Poppins',
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: FlownetColors.textPrimary,
          fontFamily: 'Poppins',
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: FlownetColors.textPrimary,
          fontFamily: 'Poppins',
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: FlownetColors.textPrimary,
          fontFamily: 'Poppins',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: FlownetColors.textSecondary,
          fontFamily: 'Poppins',
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: FlownetColors.textTertiary,
          fontFamily: 'Poppins',
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: FlownetColors.textPrimary,
          fontFamily: 'Poppins',
        ),
        labelMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: FlownetColors.textSecondary,
          fontFamily: 'Poppins',
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: FlownetColors.textTertiary,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
  
  // Utility method for status colors
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'approved':
      case 'completed':
        return FlownetColors.success;
      case 'warning':
      case 'pending':
        return FlownetColors.warning;
      case 'error':
      case 'denied':
      case 'failed':
        return FlownetColors.error;
      case 'info':
      case 'active':
        return FlownetColors.blue;
      default:
        return FlownetColors.textSecondary;
    }
  }
  
  static ThemeData get lightTheme {
    return ThemeData.light(useMaterial3: true).copyWith(
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: FlownetColors.accent,
        onPrimary: FlownetColors.onSurface,
        secondary: FlownetColors.blue,
        onSecondary: FlownetColors.onSurface,
        surface: FlownetColors.pureWhite,
        onSurface: FlownetColors.charcoalBlack,
        surfaceContainerHighest: Color(0xFFF5F5F5),
        onSurfaceVariant: FlownetColors.surfaceLight,
        error: FlownetColors.error,
        onError: FlownetColors.onSurface,
        outline: Color(0xFFE0E0E0),
        outlineVariant: FlownetColors.coolGray,
      ),

      // Typography
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: FlownetColors.graphiteGray,
          fontFamily: 'Poppins',
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: FlownetColors.graphiteGray,
          fontFamily: 'Poppins',
        ),
        
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: FlownetColors.pureWhite,
        foregroundColor: FlownetColors.charcoalBlack,
        elevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: FlownetColors.charcoalBlack,
          fontFamily: 'Poppins',
        ),
      ),

      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FlownetColors.crimsonRed,
          foregroundColor: FlownetColors.pureWhite,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return FlownetColors.crimsonRed.withAlpha((0.1 * 255).round());
              }
              return null;
            },
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FlownetColors.charcoalBlack,
          side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.black.withAlpha((0.05 * 255).round());
              }
              return null;
            },
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FlownetColors.crimsonRed,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: FlownetColors.crimsonRed,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FlownetColors.error),
        ),
        hintStyle: const TextStyle(
          color: FlownetColors.graphiteGray,
          fontSize: 16,
        ),
        labelStyle: const TextStyle(
          color: FlownetColors.graphiteGray,
          fontSize: 16,
        ),
      ),

      // Card Theme
      cardTheme: ThemeData.light().cardTheme.copyWith(
        color: FlownetColors.pureWhite,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: FlownetColors.charcoalBlack,
        size: 24,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FlownetColors.pureWhite,
        selectedItemColor: FlownetColors.crimsonRed,
        unselectedItemColor: FlownetColors.graphiteGray,
        type: BottomNavigationBarType.fixed,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FlownetColors.crimsonRed,
        foregroundColor: FlownetColors.pureWhite,
        elevation: 4,
      ),

      // Navigation Rail Theme
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: FlownetColors.pureWhite,
        selectedIconTheme: IconThemeData(
          color: FlownetColors.crimsonRed,
          size: 24,
        ),
        unselectedIconTheme: IconThemeData(
          color: FlownetColors.graphiteGray,
          size: 24,
        ),
        selectedLabelTextStyle: TextStyle(
          color: FlownetColors.crimsonRed,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: FlownetColors.graphiteGray,
          fontWeight: FontWeight.normal,
        ),
      ),

      // Drawer Theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: FlownetColors.pureWhite,
        elevation: 16,
      ),

      // ListTile Theme
      listTileTheme: ListTileThemeData(
        tileColor: FlownetColors.pureWhite,
        selectedTileColor: Color.lerp(
          FlownetColors.crimsonRed,
          FlownetColors.pureWhite,
          0.9,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        titleTextStyle: const TextStyle(
          color: FlownetColors.charcoalBlack,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: const TextStyle(
          color: FlownetColors.graphiteGray,
          fontSize: 14,
        ),
      ),
    );
  }
}
