import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';
import 'package:yamata_launcher/ui/widgets/ad_blocked_webview.dart';
import 'package:yamata_launcher/utils/http_helper.dart';
import 'package:yamata_launcher/utils/url_helper.dart';

class DownloadLinkWebExtractor extends StatefulWidget {
  String rawLink;

  DownloadLinkWebExtractor({super.key, required this.rawLink});

  @override
  State<DownloadLinkWebExtractor> createState() =>
      _DownloadLinkWebExtractorState();
}

class _DownloadLinkWebExtractorState extends State<DownloadLinkWebExtractor> {
  String get rawLink => widget.rawLink;
  var isFulfilled = false;
  String cookies = "";
  Map<String, String>? headers;

  Hoster? getHoster() {
    return DownloadSourcesRepository().getHosterForUrl(rawLink);
  }

  void handleFulfill(String url) async {
    if (isFulfilled) return;
    isFulfilled = true;
    var headers = <String, String>{
      "User-Agent": CommonHosterUtils().hosterUserAgent,
      "Referer": rawLink,
    };

    var fullUrl = UrlHelper.appendHeadersToUrl(url, headers);
    var browserCookies =
        await CookieManager.instance().getCookies(url: WebUri(url));
    if (cookies.isNotEmpty ||
        browserCookies.isNotEmpty ||
        this.headers != null) {
      var cookieMap = Map<String, String>.fromEntries(
          browserCookies.map((c) => MapEntry(c.name, c.value)));
      headers["Cookie"] = cookieMap.isNotEmpty
          ? HttpHelper().encodeCookies(cookieMap)
          : cookies;
      headers = {
        ...headers,
        if (this.headers != null) ...this.headers!,
      };
      fullUrl = UrlHelper.appendHeadersToUrl(url, headers);
    }

    context.pop(fullUrl);
  }

  bool handleUrlChange(
      String url, String cookies, Map<String, String>? headers) {
    final hoster = getHoster();
    this.cookies = cookies;
    this.headers = headers;
    if (hoster != null && hoster.isValidDirectDownloadUrl(url) == true) {
      handleFulfill(url);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AdBlockedWebView(
      rawLink: rawLink,
      title: "Follow the manual steps to successfully extract the link",
      onUrlChanged: handleUrlChange,
    );
  }
}
