import 'package:flutter/material.dart';

enum StatusTagType {
  normal,
  success,
  warning,
  error,
}

enum StatusTagSize {
  sm,
  md,
  lg,
}

class StatusTag extends StatelessWidget {
  final String text;
  final StatusTagType type;
  final StatusTagSize size;

  const StatusTag({
    super.key,
    required this.text,
    this.type = StatusTagType.normal,
    this.size = StatusTagSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    late Color bgColor;
    late Color textColor;

    switch (type) {
      case StatusTagType.normal:
        bgColor = scheme.inverseSurface;
        textColor = scheme.onSurfaceVariant;
        break;

      case StatusTagType.success:
        bgColor = Colors.green.withOpacity(0.3);
        textColor = Colors.green.shade700;
        break;

      case StatusTagType.warning:
        bgColor = Colors.orange.withOpacity(0.3);
        textColor = Colors.orange.shade800;
        break;

      case StatusTagType.error:
        bgColor = scheme.error.withOpacity(0.3);
        textColor = scheme.error;
        break;
    }

    double fontSize;
    EdgeInsets padding;

    switch (size) {
      case StatusTagSize.sm:
        fontSize = 11;
        padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 2);
        break;

      case StatusTagSize.md:
        fontSize = 12;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
        break;

      case StatusTagSize.lg:
        fontSize = 14;
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
