import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';
import 'package:yamata_launcher/services/webview_service.dart';
import 'package:yamata_launcher/ui/widgets/ad_blocked_webview.dart';
import 'package:yamata_launcher/ui/widgets/download_link_web_extractor/download_link_web_extractor_scripts.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';
import 'package:yamata_launcher/utils/url_helper.dart';
export 'package:adblocker_webview/adblocker_webview.dart';
export 'package:adblocker_webview/src/elem_hide.dart';
export 'package:adblocker_webview/src/block_resource_loading.dart';

class DownloadLinkWebExtractor extends StatefulWidget {
  String rawLink;
  DownloadLinkWebExtractor({super.key, required this.rawLink});

  @override
  State<DownloadLinkWebExtractor> createState() =>
      _DownloadLinkWebExtractorState();
}

class _DownloadLinkWebExtractorState extends State<DownloadLinkWebExtractor> {
  get rawLink => widget.rawLink;
  Hoster? getHoster() {
    return DownloadSourcesRepository().getHosterForUrl(rawLink);
  }

  var scriptsToRun = [];
  var cookies = "";

  String getDomain(String url) {
    try {
      return Uri.parse(url).host;
    } catch (e) {
      return "";
    }
  }

  void handleFulfill(String url) {
    Map<String, String> headers = {
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
    var hoster = getHoster();
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
        onUrlChanged: handleUrlChange);
  }
}
