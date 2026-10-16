import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted ice-glass panel for high-impact chrome (actions, now-playing, chips).
/// Avoid stacking these inside long scroll lists.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blurSigma = 18,
    this.opacity = 0.42,
    this.borderOpacity = 0.14,
    this.padding,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final double opacity;
  final double borderOpacity;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final scheme = ColorScheme.of(context);
    final fill =
        isDark
            ? Color.alphaBlend(scheme.primary.withOpacity(0.08), const Color(0xFF121820).withOpacity(opacity))
            : Color.alphaBlend(scheme.primary.withOpacity(0.06), Colors.white.withOpacity(0.55 + opacity * 0.2));
    final borderColor = (isDark ? Colors.white : scheme.onSurface).withOpacity(borderOpacity);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 0.9),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(isDark ? 0.10 : 0.35), Colors.white.withOpacity(0.0)],
            ),
          ),
          child: padding != null ? Padding(padding: padding!, child: child) : child,
        ),
      ),
    );
  }
}
