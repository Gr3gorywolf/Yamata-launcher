import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class PlaceHolderAction {
  final String label;
  final VoidCallback onPressed;

  PlaceHolderAction({required this.label, required this.onPressed});
}

class EmptyPlaceholder extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String? description;
  final PlaceHolderAction? action;
  const EmptyPlaceholder(
      {super.key,
      required this.icon,
      this.title,
      this.action,
      this.description});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Center(
      child: FadeIn(
        duration: Duration(seconds: 2),
        child: Container(
          constraints: BoxConstraints(maxWidth: 300),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(180),
              ),
              child: Icon(
                icon,
                size: 70,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
            SizedBox(height: 18),
            Text(
              title ?? 'No items found.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: theme.colorScheme.onSurface, fontSize: 20),
            ),
            if (description != null) ...[
              SizedBox(height: 18),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: 18),
              ElevatedButton(
                onPressed: action?.onPressed,
                child:
                    Text(action?.label ?? '', style: TextStyle(fontSize: 13)),
                style: ButtonStyle(
                  padding: WidgetStateProperty.all<EdgeInsets>(
                    EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                  ),
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              )
            ],
          ]),
        ),
      ),
    );
  }
}
