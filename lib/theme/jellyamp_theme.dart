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

/// Applies the JellyAmp component system (cards/chips/buttons/inputs/sheets/
/// lists/navigation).
ListTileThemeData _listTileTheme(ColorScheme scheme) => ListTileThemeData(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(jRadiusCard)),
  contentPadding: const EdgeInsets.symmetric(horizontal: jSpaceMd, vertical: jSpaceXs),
  minVerticalPadding: jSpaceSm,
  iconColor: scheme.onSurfaceVariant,
);

/// Consistent bottom navigation (phone) styling.
NavigationBarThemeData _navBarTheme(ColorScheme scheme) => NavigationBarThemeData(
  height: 68,
  elevation: 0,
  backgroundColor: scheme.surfaceContainer,
  indicatorColor: scheme.primaryContainer,
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  labelTextStyle: WidgetStateProperty.resolveWith(
    (states) => TextStyle(
      fontSize: 12,
      fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
      color: states.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
    ),
  ),
  iconTheme: WidgetStateProperty.resolveWith(
    (states) => IconThemeData(
      color: states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
    ),
  ),
);

/// Consistent side rail (tablet / desktop) styling — matches the bottom bar.
NavigationRailThemeData _navRailTheme(ColorScheme scheme) => NavigationRailThemeData(
  backgroundColor: scheme.surfaceContainer,
  indicatorColor: scheme.primaryContainer,
  selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
  unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
  selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
  unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
);

/// Applies the JellyAmp component system (cards/chips/buttons/inputs/sheets/
/// sliders/lists/navigation).
ThemeData applyJellyAmpTheme(ThemeData theme) {
  final scheme = theme.colorScheme;
  final isDark = theme.brightness == Brightness.dark;
  return theme.copyWith(
    useMaterial3: true,
    textTheme: jellyAmpTextTheme(theme.textTheme),
    // Slightly lifted surfaces read better in dark mode than pure black.
    scaffoldBackgroundColor: isDark ? scheme.surface : null,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(jRadiusCard)),
      color: scheme.surfaceContainerLow,
    ),
    listTileTheme: _listTileTheme(scheme),
    navigationBarTheme: _navBarTheme(scheme),
    navigationRailTheme: _navRailTheme(scheme),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(shape: const CircleBorder(), highlightColor: scheme.primary.withValues(alpha: 0.12)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(jRadiusCard)),
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(scheme.onSurfaceVariant.withValues(alpha: 0.5)),
      radius: const Radius.circular(jRadiusArtwork),
      thickness: const WidgetStatePropertyAll(6),
    ),
    chipTheme: theme.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(jRadiusArtwork)),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
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
