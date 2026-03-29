import 'package:flutter/material.dart';
import 'package:yamata_launcher/ui/widgets/focusable_element.dart';

class DialogSectionItem extends StatelessWidget {
  final String title;
  final Widget content;
  final String? helperText;
  final IconData icon;
  final bool? helperTextIsError;
  final EdgeInsetsGeometry? padding;
  final List<IconButton> actions;

  const DialogSectionItem(
      {required this.title,
      required this.content,
      this.helperText,
      required this.icon,
      required this.actions,
      this.helperTextIsError,
      this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(title,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          ),
          SizedBox(height: 5),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                constraints: BoxConstraints(minHeight: 40),
                child: Row(
                  children: [
                    Icon(icon),
                    SizedBox(width: 10),
                    Expanded(child: content),
                    Row(children: actions.map((action) => action).toList())
                  ],
                ),
              ),
            ),
          ),
          if (helperText?.isNotEmpty ?? false)
            Opacity(
                opacity: helperTextIsError == true ? 1.0 : 0.7,
                child: Container(
                  margin: EdgeInsets.only(bottom: 5, left: 4),
                  child: Text(helperText ?? '',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color:
                              helperTextIsError == true ? Colors.red : null)),
                )),
        ],
      ),
    );
  }
}
