import 'dart:ui';

import 'package:finamp/services/feedback_helper.dart';
import 'package:finamp/utils/platform_helper.dart';
import 'package:flutter/material.dart';

class HomeScreenQuickActionButton extends StatefulWidget {
  final String text;
  final String? label;
  final IconData icon;
  final double width;
  final bool vertical;
  final void Function() onPressed;
  final void Function()? onSecondaryPressed;
  final bool disabled;

  const HomeScreenQuickActionButton({
    super.key,
    required this.text,
    this.label,
    required this.icon,
    required this.width,
    this.vertical = false,
    required this.onPressed,
    this.onSecondaryPressed,
    this.disabled = false,
  });

  @override
  State<HomeScreenQuickActionButton> createState() => _HomeScreenQuickActionButtonState();
}

class _HomeScreenQuickActionButtonState extends State<HomeScreenQuickActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final accentColor = widget.disabled ? scheme.primary.withOpacity(0.5) : scheme.primary;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final radius = isDesktop ? 12.0 : 16.0;

    final buttonChildren = [
      Icon(widget.icon, size: widget.vertical ? 20 : 18, color: accentColor, weight: 1.0, applyTextScaling: true),
      Text(
        widget.text,
        style: TextStyle(
          color: (isDark ? scheme.onSurface : Color.alphaBlend(accentColor.withOpacity(0.22), scheme.onSurface))
              .withOpacity(widget.disabled ? 0.5 : 1.0),
          fontSize: 13,
          height: 1.05,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ];

    final buttonContent =
        widget.vertical
            ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: isDesktop ? 6.0 : 5.0,
              children: buttonChildren,
            )
            : Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              spacing: 8.0,
              children: buttonChildren,
            );

    final fill =
        isDark
            ? Color.alphaBlend(
              accentColor.withOpacity(widget.disabled ? 0.05 : 0.12),
              const Color(0xFF121820).withOpacity(0.55),
            )
            : Color.alphaBlend(accentColor.withOpacity(widget.disabled ? 0.06 : 0.10), Colors.white.withOpacity(0.62));

    return Semantics(
      label: widget.text,
      tooltip: widget.label,
      button: true,
      focusable: true,
      onLongPressHint: widget.label,
      excludeSemantics: true,
      container: true,
      child: SizedBox(
        width: widget.width,
        child: GestureDetector(
          onLongPress:
              widget.disabled || widget.onSecondaryPressed == null
                  ? null
                  : () {
                    FeedbackHelper.feedback(FeedbackType.selection);
                    widget.onSecondaryPressed!();
                  },
          onSecondaryTap:
              widget.disabled || widget.onSecondaryPressed == null
                  ? null
                  : () {
                    FeedbackHelper.feedback(FeedbackType.selection);
                    widget.onSecondaryPressed!();
                  },
          onTapDown: widget.disabled ? null : (_) => setState(() => _pressed = true),
          onTapUp:
              widget.disabled
                  ? null
                  : (_) {
                    setState(() => _pressed = false);
                    FeedbackHelper.feedback(FeedbackType.selection);
                    widget.onPressed();
                  },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: Colors.white.withOpacity(isDark ? 0.14 : 0.35), width: 0.9),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white.withOpacity(isDark ? 0.12 : 0.40), Colors.white.withOpacity(0.0)],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: isDesktop ? 14 : (widget.vertical ? 12 : 10),
                    ),
                    child: buttonContent,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
