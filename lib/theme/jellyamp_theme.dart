import 'package:flutter/material.dart';

/// JellyAmp design-system tokens.
///
/// Brand colors live in color_schemes.g.dart (ice #7DD3FC / charcoal #0B0F14 /
/// platinum #F4F7FA). This file holds the dimension + typography tokens and the
/// component-theme system applied on top of the base ThemeData.

// Spacing scale: 4 / 8 / 12 / 16 / 24 / 32.
const double jSpaceXs = 4;
const double jSpaceSm = 8;
const double jSpaceMd = 12;
const double jSpaceLg = 16;
const double jSpaceXl = 24;
const double jSpaceXxl = 32;

// Radius scale: artwork 8, card 12, panel 16, sheet 20.
const double jRadiusArtwork = 8;
const double jRadiusCard = 12;
const double jRadiusPanel = 16;
const double jRadiusSheet = 20;

/// Formalized Material 3 typography hierarchy (system font, deliberate weights).
TextTheme jellyAmpTextTheme(TextTheme base) => base.copyWith(
  headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
  headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
  titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
  titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
  titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
  labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
);

/// Applies the JellyAmp component system (cards/chips/buttons/inputs/sheets).
ThemeData applyJellyAmpTheme(ThemeData theme) {
  final scheme = theme.colorScheme;
  return theme.copyWith(
    useMaterial3: true,
    textTheme: jellyAmpTextTheme(theme.textTheme),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(jRadiusCard)),
    ),
    chipTheme: theme.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(jRadiusArtwork)),
      side: BorderSide(color: scheme.outlineVariant.withOpacity(0.4)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(jRadiusCard)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(jRadiusCard)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(jRadiusCard)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(jRadiusPanel), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: jSpaceLg, vertical: jSpaceMd),
    ),
    dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(jRadiusPanel))),
    bottomSheetTheme: theme.bottomSheetTheme.copyWith(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(jRadiusSheet))),
    ),
    dividerTheme: theme.dividerTheme.copyWith(space: 1, thickness: 0.5),
  );
}
