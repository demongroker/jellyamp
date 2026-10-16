import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:finamp/services/finamp_settings_helper.dart';

const jellyfinBlueColor = Color(0xFF00A4DC);
const jellyfinPurpleColor = Color(0xFFAA5CC3);

/// Jellyamp ice-glass brand accents (iOS liquid glass).
const icePrimaryColor = Color(0xFF7DD3FC);
const iceBgColor = Color(0xFF0B0F14);
const iceSurfaceColor = Color(0xFF121820);
const iceHighlightColor = Color(0xFFE0F2FE);

/// Jellyamp ember brand accents (Android M3 re-skin).
const emberPrimaryColor = Color(0xFFFF6B35);
const emberBgColor = Color(0xFF160C07);
const emberSurfaceColor = Color(0xFF221309);

/// Jellyamp light: frosted ice / platinum glass.
const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0284C7),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFCFFAFE),
  onPrimaryContainer: Color(0xFF0C4A6E),
  secondary: Color(0xFF5B6B7A),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFE2E8F0),
  onSecondaryContainer: Color(0xFF1E293B),
  tertiary: Color(0xFF0EA5E9),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFE0F2FE),
  onTertiaryContainer: Color(0xFF0C4A6E),
  error: Color(0xFFBA1A1A),
  errorContainer: Color(0xFFFFDAD6),
  onError: Color(0xFFFFFFFF),
  onErrorContainer: Color(0xFF410002),
  background: Color(0xFFF4F7FA),
  onBackground: Color(0xFF0F172A),
  surface: Color(0xFFF4F7FA),
  surfaceContainerHighest: Color(0xFFE8EEF4),
  onSurface: Color(0xFF0F172A),
  surfaceVariant: Color(0xFFD9E2EC),
  onSurfaceVariant: Color(0xFF475569),
  outline: Color(0xFF94A3B8),
  onInverseSurface: Color(0xFFF1F5F9),
  inverseSurface: Color(0xFF1E293B),
  inversePrimary: Color(0xFF7DD3FC),
  shadow: Color(0xFF000000),
  surfaceTint: icePrimaryColor,
  outlineVariant: Color(0xFFCBD5E1),
  scrim: Color(0xFF000000),
);

/// Jellyamp dark: liquid ice glass on charcoal.
const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: icePrimaryColor,
  onPrimary: Color(0xFF0C4A6E),
  primaryContainer: Color(0xFF0369A1),
  onPrimaryContainer: Color(0xFFE0F2FE),
  secondary: Color(0xFFA5B4C8),
  onSecondary: Color(0xFF1E293B),
  secondaryContainer: Color(0xFF334155),
  onSecondaryContainer: Color(0xFFE2E8F0),
  tertiary: Color(0xFFBAE6FD),
  onTertiary: Color(0xFF0C4A6E),
  tertiaryContainer: Color(0xFF0E7490),
  onTertiaryContainer: Color(0xFFECFEFF),
  error: Color(0xFFFFB4AB),
  errorContainer: Color(0xFF93000A),
  onError: Color(0xFF690005),
  onErrorContainer: Color(0xFFFFDAD6),
  background: iceBgColor,
  onBackground: Color(0xFFF0F6FA),
  surface: iceBgColor,
  surfaceContainerHighest: iceSurfaceColor,
  onSurface: Color(0xFFF0F6FA),
  surfaceVariant: Color(0xFF1E293B),
  onSurfaceVariant: Color(0xFFA5B4C8),
  outline: Color(0xFF64748B),
  onInverseSurface: Color(0xFF0B0F14),
  inverseSurface: Color(0xFFE2E8F0),
  inversePrimary: Color(0xFF0284C7),
  shadow: Color(0xFF000000),
  surfaceTint: icePrimaryColor,
  outlineVariant: Color(0xFF334155),
  scrim: Color(0xFF000000),
);

/// If [color] is provided -> returns a generated color scheme
/// otherwise falls back to default color schemes
/// [lightColorScheme] or [darkColorScheme]
ColorScheme getColorScheme(Color? color, Brightness brightness, bool amoledTheme) {
  // A user-picked custom accent always wins; otherwise use the platform brand
  // — ember M3 on Android, curated liquid ice glass elsewhere (iOS).
  final hasCustomAccent = color != null && color != icePrimaryColor;

  ColorScheme scheme;
  if (hasCustomAccent) {
    scheme = ColorScheme.fromSeed(
      seedColor: color!,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
  } else if (Platform.isAndroid) {
    // Ember brand with warm charcoal surfaces.
    scheme = ColorScheme.fromSeed(
      seedColor: emberPrimaryColor,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      background: brightness == Brightness.dark ? emberBgColor : const Color(0xFFFFF6F0),
      surface: brightness == Brightness.dark ? emberBgColor : const Color(0xFFFFF6F0),
      surfaceContainerHighest: brightness == Brightness.dark ? emberSurfaceColor : const Color(0xFFFFE5D8),
    );
  } else {
    // Curated liquid ice glass (hand-tuned charcoal surfaces, kept intact).
    scheme = brightness == Brightness.dark ? darkColorScheme : lightColorScheme;
  }

  if (amoledTheme && brightness == Brightness.dark) {
    scheme = scheme.copyWith(background: const Color(0xFF000000), surface: const Color(0xFF000000));
  }

  return scheme;
}
