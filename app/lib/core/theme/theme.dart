import 'package:flutter/material.dart';

/// Night-first palette (plan §12.1). Score colours are paired with words/icons
/// everywhere — never colour-only (plan §12.4 accessibility).
class NwColors {
  static const night = Color(0xFF0B1220);
  static const surface = Color(0xFF131C2E);
  static const surfaceHigh = Color(0xFF1C2740);
  static const primary = Color(0xFF2DD4BF);
  static const primaryDim = Color(0xFF0F766E);
  static const safe = Color(0xFF2DD4BF);
  static const moderate = Color(0xFFFBBF24);
  static const risky = Color(0xFFF87171);
  static const limited = Color(0xFF94A3B8);
  static const text = Color(0xFFE6EDF7);
  static const textMuted = Color(0xFF9AA8BE);
  static const danger = Color(0xFFEF4444);
}

class NwTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: NwColors.night,
      colorScheme: base.colorScheme.copyWith(
        primary: NwColors.primary,
        secondary: NwColors.primaryDim,
        surface: NwColors.surface,
        error: NwColors.danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: NwColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NwColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: NwColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NwColors.primary,
          foregroundColor: NwColors.night,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: NwColors.text,
        displayColor: NwColors.text,
      ),
    );
  }

  static Color scoreColor(int score) {
    if (score >= 70) return NwColors.safe;
    if (score >= 45) return NwColors.moderate;
    return NwColors.risky;
  }

  static String scoreWord(int score) {
    if (score >= 70) return 'good';
    if (score >= 45) return 'moderate';
    return 'poor';
  }

  static Color confidenceColor(double confidence) {
    if (confidence >= 0.6) return NwColors.safe;
    if (confidence >= 0.35) return NwColors.moderate;
    return NwColors.limited;
  }
}
