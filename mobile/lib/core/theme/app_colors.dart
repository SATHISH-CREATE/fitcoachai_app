import 'package:flutter/material.dart';

class AppColors {
  // Primary Orange - VIBRANT & PREMIUM
  static const Color primary = Color(0xFFFF6D00);
  static const Color primaryLight = Color(0xFFFF9E00);
  static const Color primaryDark = Color(0xFFE65100);
  static const Color primarySoft = Color(0xFFFFE0B2);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF212121);
  static const Color accent = Color(0xFFFFAB40);
  
  // Backgrounds - Warm Cream & Whites
  static const Color bgMain = Color(0xFFFDFDFD);
  static const Color bgCream = Color(0xFFFFF9F2);
  static const Color bgSoft = Color(0xFFF5F5F5);
  
  // Surface / Cards
  static const Color surface = Colors.white;
  static const Color cardShadow = Color(0x15000000);
  static const Color border = Color(0xFFEEEEEE);
  static const Color cardBorder = Color(0xFFF1F1F1);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textMuted = Color(0xFF9E9E9E);
  static const Color textContrast = Colors.white;
  
  // Functional Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF2196F3);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF9E00), Color(0xFFFF6D00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient softOrangeGradient = LinearGradient(
    colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFFFF9F2), Color(0xFFFDFDFD)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Modern Decorations
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration get orangeCardDecoration => BoxDecoration(
    gradient: primaryGradient,
    borderRadius: BorderRadius.circular(24),
    boxShadow: [
      BoxShadow(
        color: primary.withOpacity(0.3),
        blurRadius: 15,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static BoxDecoration get iconCircleDecoration => BoxDecoration(
    color: primary.withOpacity(0.1),
    shape: BoxShape.circle,
  );
  
  // Compatibility getters for existing code that might use old names
  static Color get bgDark => bgMain;
  static Color get cardBg => surface;
  static Color get textMain => textPrimary;
  static Color get separator => border;
  static Color get divider => border;
}

