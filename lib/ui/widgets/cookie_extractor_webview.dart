import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:yamata_launcher/ui/widgets/ad_blocked_webview.dart';
import 'package:yamata_launcher/utils/http_helper.dart';

class CookieExtractorWebview extends StatefulWidget {
  String url;
  CookieExtractorWebview({super.key, required this.url});

  @override
  State<CookieExtractorWebview> createState() => _CookieExtractorWebviewState();
}

class _CookieExtractorWebviewState extends State<CookieExtractorWebview> {
  @override
  Widget build(BuildContext context) {
    return AdBlockedWebView(
      rawLink: widget.url,
      title: "Sign in to your account then click on the done button",
      onDone: (String url, String cookies) async {
        var browserCookies =
            await CookieManager.instance().getCookies(url: WebUri(url));
        var cookieMap = Map<String, String>.fromEntries(
            browserCookies.map((c) => MapEntry(c.name, c.value)));
        Navigator.of(context).pop(HttpHelper().encodeCookies(cookieMap));
      },
    );
  }
}
