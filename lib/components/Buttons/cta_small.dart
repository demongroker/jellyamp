import 'package:finamp/services/feedback_helper.dart';
import 'package:flutter/material.dart';

class CTASmall extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool vertical;
  final bool disabled;
  final void Function() onPressed;

  const CTASmall({
    super.key,
    required this.text,
    required this.icon,
    this.vertical = false,
    this.disabled = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor =
        disabled ? Theme.of(context).colorScheme.primary.withOpacity(0.5) : Theme.of(context).colorScheme.primary;
    return FilledButton(
      onPressed:
          disabled
              ? null
              : () {
                FeedbackHelper.feedback(FeedbackType.selection);
                onPressed();
              },
      style: ButtonStyle(
        elevation: WidgetStateProperty.all(0),
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: accentColor.withOpacity(0.22), width: 0.8),
          ),
        ),
        padding: WidgetStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
        backgroundColor: WidgetStateProperty.all<Color>(
          Theme.brightnessOf(context) == Brightness.dark
              ? Color.alphaBlend(accentColor.withOpacity(disabled ? 0.06 : 0.14), Theme.of(context).colorScheme.surface)
              : Color.alphaBlend(accentColor.withOpacity(0.14), Colors.white).withOpacity(disabled ? 0.5 : 1.0),
        ),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        direction: vertical ? Axis.vertical : Axis.horizontal,
        alignment: vertical ? WrapAlignment.center : WrapAlignment.start,
        children: [
          Icon(icon, size: 20, color: accentColor, weight: 1.0),
          const SizedBox(width: 8, height: 4),
          Text(
            text,
            style: TextStyle(
              color: (Theme.brightnessOf(context) == Brightness.light
                      ? Color.alphaBlend(accentColor.withOpacity(0.33), Colors.black)
                      : Colors.white)
                  .withOpacity(disabled ? 0.5 : 1.0),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
