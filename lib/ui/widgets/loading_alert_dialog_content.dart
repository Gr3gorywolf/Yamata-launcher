import 'package:flutter/material.dart';

class LoadingAlertDialogContent extends StatelessWidget {
  final String text;
  final double? progress;

  const LoadingAlertDialogContent({
    super.key,
    required this.text,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: progress),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
