import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WrappedLinkText extends StatelessWidget {
  final String text;
  final String link;
  final String? linkText;
  const WrappedLinkText(
      {super.key, required this.text, required this.link, this.linkText});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: text,
          ),
          TextSpan(
            text: "  ",
          ),
          TextSpan(
            text: linkText ?? link,
            mouseCursor: SystemMouseCursors.click,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _openUrl(link);
              },
          ),
        ],
      ),
      softWrap: true,
    );
  }
}
