import 'package:flutter/material.dart';
import 'package:pos/themes/styles/styles.dart';

class PosButton extends StatelessWidget {
  const PosButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
    this.iconSize,
    this.padding = const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
    this.textStyle,
    this.width,
    this.height,
  });

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? iconColor;
  final double? iconSize;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? theme.colorScheme.primary,
        foregroundColor: textColor ?? theme.colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        padding: padding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon,
                size: iconSize,
                color: iconColor ?? textColor ?? theme.colorScheme.onPrimary),
          if (icon != null) const SizedBox(width: 8.0),
          Text(
            text,
            style: textStyle ?? Styles.inputTextStyleWhite,
          ),
        ],
      ),
    );
  }
}
