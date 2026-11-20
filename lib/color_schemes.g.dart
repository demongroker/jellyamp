import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:finamp/services/finamp_settings_helper.dart';

const jellyfinBlueColor = Color(0xFF00A4DC);
const jellyfinPurpleColor = Color(0xFFAA5CC3);

/// JellyAmp brand accents — navy + gold, shared with Hermes, VideoDroid and Vela.
/// Values: ~/.hermes/plans/design-tokens-navy-gold.md. Gold never carries text on a
/// light surface; the light scheme uses the darkened gold 7A5F14.
const brandPrimaryColor = Color(0xFFD4AF37);
const brandBgColor = Color(0xFF0B1220);
const brandSurfaceColor = Color(0xFF1B2740);
const brandHighlightColor = Color(0xFFF0DFA8);

/// Jellyamp ember brand accents (Android M3 re-skin).
const emberPrimaryColor = Color(0xFFFF6B35);
const emberBgColor = Color(0xFF160C07);
const emberSurfaceColor = Color(0xFF221309);

/// Jellyamp light: frosted ice / platinum glass.
const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF7A5F14),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFF5E7BE),
  onPrimaryContainer: Color(0xFF3A2E10),
  secondary: Color(0xFF41547A),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDDE4F0),
  onSecondaryContainer: Color(0xFF1A2740),
  tertiary: Color(0xFF8A6D1F),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFF6E5CC),
  onTertiaryContainer: Color(0xFF3C2A0D),
  error: Color(0xFFB3261E),
  errorContainer: Color(0xFFFFDAD6),
  onError: Color(0xFFFFFFFF),
  onErrorContainer: Color(0xFF410002),
  background: Color(0xFFF7F8FA),
  onBackground: Color(0xFF101828),
  surface: Color(0xFFFFFFFF),
  surfaceContainerHighest: Color(0xFFE7EBF2),
  onSurface: Color(0xFF101828),
  surfaceVariant: Color(0xFFEEF1F6),
  onSurfaceVariant: Color(0xFF48566E),
  outline: Color(0xFFC7CFDB),
  onInverseSurface: Color(0xFFE6EDF7),
  inverseSurface: Color(0xFF1B2740),
  inversePrimary: Color(0xFFD4AF37),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0xFF7A5F14),
  outlineVariant: Color(0xFFDDE3EC),
  scrim: Color(0xFF000000),
);

/// JellyAmp dark: gold on navy.
const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: brandPrimaryColor,
  onPrimary: Color(0xFF0B1220),
  primaryContainer: Color(0xFF3A2E10),
  onPrimaryContainer: Color(0xFFF0DFA8),
  secondary: Color(0xFF8FA3C8),
  onSecondary: Color(0xFF0B1220),
  secondaryContainer: Color(0xFF24334D),
  onSecondaryContainer: Color(0xFFD7E1F2),
  tertiary: Color(0xFFE0B478),
  onTertiary: Color(0xFF3C2A0D),
  tertiaryContainer: Color(0xFF4A3720),
  onTertiaryContainer: Color(0xFFF6E5CC),
  error: Color(0xFFF85149),
  errorContainer: Color(0xFF5C1A16),
  onError: Color(0xFF0B1220),
  onErrorContainer: Color(0xFFFFDAD6),
  background: brandBgColor,
  onBackground: Color(0xFFE6EDF7),
  surface: Color(0xFF111A2B),
  surfaceContainerHighest: brandSurfaceColor,
  onSurface: Color(0xFFE6EDF7),
  surfaceVariant: Color(0xFF1B2740),
  onSurfaceVariant: Color(0xFFA9B6CC),
  outline: Color(0xFF2A3A57),
  onInverseSurface: Color(0xFF0B1220),
  inverseSurface: Color(0xFFE6EDF7),
  inversePrimary: Color(0xFF7A5F14),
  shadow: Color(0xFF000000),
  surfaceTint: brandPrimaryColor,
  outlineVariant: Color(0xFF22304A),
  scrim: Color(0xFF000000),
);

/// If [color] is provided -> returns a generated color scheme
/// otherwise falls back to default color schemes
/// [lightColorScheme] or [darkColorScheme]
ColorScheme getColorScheme(Color? color, Brightness brightness, bool amoledTheme) {
  // A user-picked custom accent always wins; otherwise the curated navy + gold
  // brand applies on every platform.
  final hasCustomAccent = color != null && color != brandPrimaryColor;

  ColorScheme scheme;
  if (hasCustomAccent) {
    scheme = ColorScheme.fromSeed(
      seedColor: color!,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
  } else {
    // One identity on every platform: curated navy + gold. Android used to force the
    // ember preset here, which meant the brand never matched the other apps on the
    // owner's phone. Ember remains available as a user-picked accent.
    scheme = brightness == Brightness.dark ? darkColorScheme : lightColorScheme;
  }

  if (amoledTheme && brightness == Brightness.dark) {
    scheme = scheme.copyWith(background: const Color(0xFF000000), surface: const Color(0xFF000000));
  }

  return scheme;
}
