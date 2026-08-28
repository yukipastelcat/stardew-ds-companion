import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The fan-made "Stardew Valley" pixel font from FontStruct
/// (https://fontstruct.com/fontstructions/show/1254619/stardew_valley,
/// by "RRDome", FontStruct Non-Commercial License — personal/non-commercial
/// use only; license + readme bundled alongside the font file under
/// assets/fonts/license/). Registered via pubspec.yaml as the
/// `StardewValley` font family.
///
/// Falls back to Pixelify Sans (the previous open-license pixel-style
/// stand-in — see `main.dart`'s prior comment) for any glyph the
/// FontStruct font doesn't cover, since it's a small hand-built set
/// rather than a full Latin character set.
const String kStardewFontFamily = 'StardewValley';
const String _kPixelifySansFamily = 'PixelifySans';

/// Builds a single [TextStyle] using the Stardew Valley pixel font with
/// a Pixelify Sans fallback. Mirrors `GoogleFonts.pixelifySans`'s most
/// commonly used parameters so existing call sites can swap in place.
TextStyle stardewFont({
  double? fontSize,
  FontWeight? fontWeight,
  FontStyle? fontStyle,
  Color? color,
  double? height,
  double? letterSpacing,
  double? wordSpacing,
  TextDecoration? decoration,
}) {
  final fallback = GoogleFonts.pixelifySans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    decoration: decoration,
  );
  return fallback.copyWith(
    fontFamily: kStardewFontFamily,
    fontFamilyFallback: [
      _kPixelifySansFamily,
      ...?fallback.fontFamilyFallback,
    ],
  );
}

/// Builds a full [TextTheme] using the Stardew Valley pixel font with a
/// Pixelify Sans fallback, for `MaterialApp.theme.textTheme`.
TextTheme stardewTextTheme([TextTheme? base]) {
  final pixelifyTheme = GoogleFonts.pixelifySansTextTheme(base);

  TextStyle? withStardewFallback(TextStyle? style) {
    if (style == null) return null;
    return style.copyWith(
      fontFamily: kStardewFontFamily,
      fontFamilyFallback: [
        _kPixelifySansFamily,
        ...?style.fontFamilyFallback,
      ],
    );
  }

  return pixelifyTheme.copyWith(
    displayLarge: withStardewFallback(pixelifyTheme.displayLarge),
    displayMedium: withStardewFallback(pixelifyTheme.displayMedium),
    displaySmall: withStardewFallback(pixelifyTheme.displaySmall),
    headlineLarge: withStardewFallback(pixelifyTheme.headlineLarge),
    headlineMedium: withStardewFallback(pixelifyTheme.headlineMedium),
    headlineSmall: withStardewFallback(pixelifyTheme.headlineSmall),
    titleLarge: withStardewFallback(pixelifyTheme.titleLarge),
    titleMedium: withStardewFallback(pixelifyTheme.titleMedium),
    titleSmall: withStardewFallback(pixelifyTheme.titleSmall),
    bodyLarge: withStardewFallback(pixelifyTheme.bodyLarge),
    bodyMedium: withStardewFallback(pixelifyTheme.bodyMedium),
    bodySmall: withStardewFallback(pixelifyTheme.bodySmall),
    labelLarge: withStardewFallback(pixelifyTheme.labelLarge),
    labelMedium: withStardewFallback(pixelifyTheme.labelMedium),
    labelSmall: withStardewFallback(pixelifyTheme.labelSmall),
  );
}
