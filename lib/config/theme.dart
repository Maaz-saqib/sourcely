/// Sourcely Design System — Theme Configuration
/// Minimalist, professional design with Light and Dark modes.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Core brand colors
class SourcelyColors {
  SourcelyColors._();

  // Primary palette (Sage Green)
  static const Color primary = Color(0xFF778873);
  static const Color secondary = Color(0xFFA1BC98);
  static const Color tertiary = Color(0xFFDCCFC0);
  static const Color backgroundLight = Color(0xFFFDF6ED);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color processing = Color(0xFF778873);

  // Common Text
  static const Color textLightPrimary = Color(0xFF2C332B);
  static const Color textLightSecondary = Color(0xFF5A6658);
  static const Color textLightMuted = Color(0xFF8A9988);

  static const Color textDarkPrimary = Color(0xFFE8EBE7);
  static const Color textDarkSecondary = Color(0xFFB5BEB4);
  static const Color textDarkMuted = Color(0xFF8A9988);

  // Backgrounds & Surfaces
  static const Color backgroundDark = Color(0xFF1E211D);
  static const Color surfaceDark = Color(0xFF262A25);
  static const Color surfaceLight = Colors.white;

  // Borders
  static const Color borderLight = Color(0xFFDCCFC0);
  static const Color borderDark = Color(0xFF3B413A);
}

/// App theme builder
class SourcelyTheme {
  SourcelyTheme._();

  // Shared text theme structure
  static TextTheme _buildTextTheme(Color primary, Color secondary, Color muted) {
    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: 0.5,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: SourcelyColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: SourcelyColors.primary,
        secondary: SourcelyColors.secondary,
        surface: SourcelyColors.surfaceLight,
        error: SourcelyColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.black87,
        onSurface: SourcelyColors.textLightPrimary,
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(
        SourcelyColors.textLightPrimary,
        SourcelyColors.textLightSecondary,
        SourcelyColors.textLightMuted,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: SourcelyColors.backgroundLight,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: SourcelyColors.textLightPrimary,
        ),
        iconTheme: const IconThemeData(color: SourcelyColors.textLightPrimary),
      ),
      cardTheme: CardThemeData(
        color: SourcelyColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SourcelyColors.borderLight, width: 1),
        ),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(SourcelyColors.primary, Colors.white),
      outlinedButtonTheme: _outlinedButtonTheme(SourcelyColors.primary, SourcelyColors.borderLight),
      inputDecorationTheme: _inputDecorationTheme(
        fillColor: Colors.white,
        borderColor: SourcelyColors.borderLight,
        focusedColor: SourcelyColors.primary,
        hintColor: SourcelyColors.textLightMuted,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: SourcelyColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SourcelyColors.textLightPrimary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SourcelyColors.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SourcelyColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SourcelyColors.borderLight,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: SourcelyColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: SourcelyColors.primary,
        secondary: SourcelyColors.secondary,
        surface: SourcelyColors.surfaceDark,
        error: SourcelyColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.black87,
        onSurface: SourcelyColors.textDarkPrimary,
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(
        SourcelyColors.textDarkPrimary,
        SourcelyColors.textDarkSecondary,
        SourcelyColors.textDarkMuted,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: SourcelyColors.backgroundDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: SourcelyColors.textDarkPrimary,
        ),
        iconTheme: const IconThemeData(color: SourcelyColors.textDarkPrimary),
      ),
      cardTheme: CardThemeData(
        color: SourcelyColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: SourcelyColors.borderDark, width: 1),
        ),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(SourcelyColors.primary, Colors.white),
      outlinedButtonTheme: _outlinedButtonTheme(SourcelyColors.secondary, SourcelyColors.borderDark),
      inputDecorationTheme: _inputDecorationTheme(
        fillColor: SourcelyColors.surfaceDark,
        borderColor: SourcelyColors.borderDark,
        focusedColor: SourcelyColors.primary,
        hintColor: SourcelyColors.textDarkMuted,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: SourcelyColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SourcelyColors.surfaceDark,
        contentTextStyle: GoogleFonts.inter(color: SourcelyColors.textDarkPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SourcelyColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SourcelyColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: SourcelyColors.borderDark,
        thickness: 1,
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(Color bg, Color fg) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Color fg, Color border) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme({
    required Color fillColor,
    required Color borderColor,
    required Color focusedColor,
    required Color hintColor,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: focusedColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: SourcelyColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: GoogleFonts.inter(
        color: hintColor,
        fontSize: 14,
      ),
    );
  }
}

/// Minimal card decoration replacing glassmorphism
BoxDecoration minimalCardDecoration(BuildContext context, {double borderRadius = 12}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? SourcelyColors.surfaceDark : SourcelyColors.surfaceLight,
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: isDark ? SourcelyColors.borderDark : SourcelyColors.borderLight,
      width: 1,
    ),
  );
}

/// Fallback text widget mapping for removed GradientText
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    this.style,
  });

  final String text;
  final Gradient gradient; // Kept for compatibility but ignored
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style?.copyWith(color: SourcelyColors.primary),
    );
  }
}
