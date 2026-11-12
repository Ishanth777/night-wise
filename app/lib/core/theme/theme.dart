import 'package:flutter/material.dart';

/// NightWise design system — "quiet map" language.
///
/// A warm paper canvas, near-black ink, one lime accent and a grayscale map.
/// The palette is deliberately narrow: safety states always pair colour with a
/// word or icon, never colour alone (accessibility requirement).
class NwColors {
  const NwColors._();

  // Surfaces
  static const canvas = Color(0xFFECECE6);
  static const canvasDeep = Color(0xFFE2E3DA);
  static const surface = Color(0xFFF8F8F3);
  static const panel = Color(0xFFFFFFFF);
  static const ink = Color(0xFF121410);
  static const inkSoft = Color(0xFF2C2F28);
  static const inkMuted = Color(0xFF4A4E43);

  // Accent
  static const accent = Color(0xFFC8F25B);
  static const accentSoft = Color(0xFFE7FAB6);
  static const accentDeep = Color(0xFF9CCB26);

  // Lines & type
  static const line = Color(0xFFE2E3DA);
  static const lineStrong = Color(0xFFCFD1C5);
  static const text = ink;
  static const textMuted = Color(0xFF71766A);
  static const textFaint = Color(0xFF9A9E93);
  static const onDark = Color(0xFFF7F8F1);
  static const onDarkMuted = Color(0xFFA4A99D);

  // Semantic
  static const danger = Color(0xFFD94F3D);
  static const dangerSoft = Color(0xFFFBE7E2);
  static const warning = Color(0xFFD9952B);
  static const warningSoft = Color(0xFFFBF0DA);
  static const info = Color(0xFF3D63C9);
  static const infoSoft = Color(0xFFE8EDFB);
  static const success = Color(0xFF4C8A38);

  // Legacy aliases kept so older widgets keep compiling while they are
  // migrated to the new tokens.
  static const night = ink;
  static const surfaceHigh = canvas;
  static const primary = accent;
  static const primaryDim = accentDeep;
  static const safe = ink;
  static const moderate = warning;
  static const risky = danger;
  static const limited = textMuted;
}

class NwRadii {
  const NwRadii._();
  static const sheet = 30.0;
  static const card = 24.0;
  static const control = 16.0;
  static const chip = 999.0;
}

class NwText {
  const NwText._();

  static const display = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontWeight: FontWeight.w700,
    fontSize: 34,
    height: 1.05,
    letterSpacing: -1.2,
    color: NwColors.text,
  );

  static const h1 = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontWeight: FontWeight.w700,
    fontSize: 27,
    height: 1.1,
    letterSpacing: -0.8,
    color: NwColors.text,
  );

  static const h2 = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontWeight: FontWeight.w600,
    fontSize: 21,
    height: 1.2,
    letterSpacing: -0.4,
    color: NwColors.text,
  );

  static const h3 = TextStyle(
    fontFamily: 'SpaceGrotesk',
    fontWeight: FontWeight.w600,
    fontSize: 16.5,
    height: 1.25,
    letterSpacing: -0.2,
    color: NwColors.text,
  );

  static const body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 1.45,
    color: NwColors.text,
  );

  static const bodyMuted = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    height: 1.45,
    color: NwColors.textMuted,
  );

  static const small = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11.5,
    height: 1.4,
    color: NwColors.textMuted,
  );

  static const label = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 12.5,
    letterSpacing: 0.1,
    color: NwColors.text,
  );

  static const eyebrow = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 10.5,
    letterSpacing: 1.4,
    color: NwColors.textMuted,
  );

  static const button = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
    fontSize: 14.5,
    letterSpacing: -0.1,
  );
}

class NwTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: NwColors.accent,
      brightness: Brightness.light,
      primary: NwColors.ink,
      onPrimary: NwColors.onDark,
      secondary: NwColors.accent,
      onSecondary: NwColors.ink,
      surface: NwColors.surface,
      onSurface: NwColors.ink,
      outline: NwColors.lineStrong,
      error: NwColors.danger,
    );

    return base.copyWith(
      scaffoldBackgroundColor: NwColors.canvas,
      colorScheme: scheme,
      canvasColor: NwColors.canvas,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: NwColors.ink,
        titleTextStyle: NwText.h2,
        iconTheme: IconThemeData(color: NwColors.ink, size: 21),
      ),
      cardTheme: CardThemeData(
        color: NwColors.panel,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NwRadii.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: NwColors.panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          color: NwColors.textFaint,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          color: NwColors.textMuted,
          fontSize: 13,
        ),
        prefixIconColor: NwColors.textMuted,
        suffixIconColor: NwColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NwRadii.control),
          borderSide: const BorderSide(color: NwColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NwRadii.control),
          borderSide: const BorderSide(color: NwColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NwRadii.control),
          borderSide: const BorderSide(color: NwColors.ink, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NwRadii.control),
          borderSide: const BorderSide(color: NwColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NwRadii.control),
          borderSide: const BorderSide(color: NwColors.danger, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NwColors.ink,
          foregroundColor: NwColors.onDark,
          disabledBackgroundColor: NwColors.lineStrong,
          disabledForegroundColor: NwColors.textFaint,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NwRadii.control),
          ),
          textStyle: NwText.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NwColors.ink,
          minimumSize: const Size.fromHeight(50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: const BorderSide(color: NwColors.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NwRadii.control),
          ),
          textStyle: NwText.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NwColors.ink,
          textStyle: NwText.label,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: NwColors.panel,
        selectedColor: NwColors.ink,
        disabledColor: NwColors.line,
        surfaceTintColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: NwColors.ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: NwColors.onDark,
        ),
        side: const BorderSide(color: NwColors.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NwRadii.chip),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        showCheckmark: false,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: NwColors.ink,
        inactiveTrackColor: NwColors.line,
        thumbColor: NwColors.accent,
        overlayColor: NwColors.accent.withValues(alpha: 0.18),
        trackHeight: 5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        valueIndicatorColor: NwColors.ink,
        valueIndicatorTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          color: NwColors.onDark,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NwColors.accent
              : NwColors.panel,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NwColors.ink
              : NwColors.lineStrong,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dividerTheme: const DividerThemeData(
        color: NwColors.line,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NwColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: NwColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(NwRadii.sheet)),
        ),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: NwColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NwRadii.card),
        ),
        titleTextStyle: NwText.h2,
        contentTextStyle: NwText.body,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: NwColors.ink,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: NwColors.onDark,
          fontSize: 13,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        insetPadding: const EdgeInsets.all(16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NwColors.ink,
        linearTrackColor: NwColors.line,
        circularTrackColor: NwColors.line,
      ),
      textTheme: base.textTheme
          .apply(
            fontFamily: 'Inter',
            bodyColor: NwColors.text,
            displayColor: NwColors.text,
          )
          .copyWith(
            headlineLarge: NwText.display,
            headlineMedium: NwText.h1,
            headlineSmall: NwText.h2,
            titleLarge: NwText.h2,
            titleMedium: NwText.h3,
            bodyLarge: NwText.body,
            bodyMedium: NwText.bodyMuted,
            labelLarge: NwText.button,
            labelMedium: NwText.label,
            labelSmall: NwText.small,
          ),
    );
  }

  // Backwards-compatible entry point used by app.dart.
  static ThemeData dark() => light();

  /// Colour used for score bars and map geometry. Always paired with a word.
  static Color scoreColor(int score) {
    if (score >= 70) return NwColors.accentDeep;
    if (score >= 45) return NwColors.warning;
    return NwColors.danger;
  }

  static Color scoreSoft(int score) {
    if (score >= 70) return NwColors.accentSoft;
    if (score >= 45) return NwColors.warningSoft;
    return NwColors.dangerSoft;
  }

  static String scoreWord(int score) {
    if (score >= 70) return 'good';
    if (score >= 45) return 'moderate';
    return 'low';
  }

  static String scoreLabel(int score) {
    if (score >= 70) return 'Comfortable';
    if (score >= 45) return 'Moderate';
    return 'Limited data';
  }

  static Color confidenceColor(double confidence) {
    if (confidence >= 0.6) return NwColors.ink;
    if (confidence >= 0.35) return NwColors.warning;
    return NwColors.textMuted;
  }
}