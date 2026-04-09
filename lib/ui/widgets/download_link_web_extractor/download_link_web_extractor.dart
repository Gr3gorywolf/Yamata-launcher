import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';
import 'package:yamata_launcher/ui/widgets/ad_blocked_webview.dart';
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

  String cookies = "";

  Hoster? getHoster() {
    return DownloadSourcesRepository().getHosterForUrl(rawLink);
  }

  void handleFulfill(String url) {
    final headers = <String, String>{
      "User-Agent": CommonHosterUtils().hosterUserAgent,
      "Referer": rawLink,
    };

    var fullUrl = UrlHelper.appendHeadersToUrl(url, headers);
    if (cookies.isNotEmpty) {
      headers["Cookie"] = cookies;
      fullUrl = UrlHelper.appendHeadersToUrl(fullUrl, headers);
    }

    context.pop(fullUrl);
  }

  bool handleUrlChange(String url, String cookies) {
    final hoster = getHoster();
    this.cookies = cookies;
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
