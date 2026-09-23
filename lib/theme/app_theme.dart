import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color cardBg = Color(0xFF161F30);
  static const Color cardBorder = Color(0xFF26334D);
  static const Color primaryCyan = Color(0xFF00E5FF);
  static const Color primaryPurple = Color(0xFF8A2BE2);
  static const Color accentNeon = Color(0xFF00FF88);
  static const Color textWhite = Color(0xFFF3F4F6);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color dangerRed = Color(0xFFFF4D4D);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryCyan,
        secondary: primaryPurple,
        surface: cardBg,
        error: dangerRed,
        onPrimary: Colors.black,
        onSurface: textWhite,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(color: textWhite, fontWeight: FontWeight.bold),
        titleLarge: GoogleFonts.outfit(color: textWhite, fontWeight: FontWeight.w700),
        bodyLarge: GoogleFonts.outfit(color: textWhite, fontSize: 16),
        bodyMedium: GoogleFonts.outfit(color: textMuted, fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: textWhite),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: cardBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryCyan, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: dangerRed, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryCyan,
          foregroundColor: Colors.black,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
