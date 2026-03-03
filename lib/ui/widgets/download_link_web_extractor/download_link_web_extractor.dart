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
import 'package:yamata_launcher/ui/widgets/download_link_web_extractor/download_link_web_extractor_scripts.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';
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
    var fullUrl =
        "${url}||headers:User-Agent:${CommonHosterUtils().hosterUserAgent}^Referer:$rawLink";

    if (cookies.isNotEmpty) {
      fullUrl += "^Cookie: $cookies";
    }
    context.pop(url);
  }

  late final WebViewController controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {},
        onUrlChange: (UrlChange url) {
          var hoster = getHoster();
          if (hoster != null &&
              hoster.isValidDirectDownloadUrl(url.url ?? "") == true) {
            handleFulfill(url.url ?? "");
          }
        },
        onPageStarted: (String url) async {
          await clearAds();
          await controller.runJavaScript(
            getResourceLoadingBlockerScript(WebviewService.blockingRules),
          );
          print("Page started loading: $url");
        },
        onPageFinished: (String url) async {
          print("Page finished loading: $url");
          await clearAds();
        },
        onHttpError: (HttpResponseError error) {},
        onWebResourceError: (WebResourceError error) {},
        onNavigationRequest: (NavigationRequest request) {
          var host = Uri.parse(rawLink).host;
          var hoster = getHoster();
          if (hoster != null &&
              hoster.isValidDirectDownloadUrl(request.url) == true) {
            handleFulfill(request.url);
            return NavigationDecision.prevent;
          }

          if (!Uri.parse(request.url).host.contains(host)) {
            return NavigationDecision.prevent;
          }

          if (WebviewService.adBlockManager.isBlockedDomain(request.url)) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );

  Future<void> clearAds() async {
    for (var script in scriptsToRun) {
      await controller.runJavaScript(script);
    }
  }

  Future initialize() async {
    scriptsToRun = [
      await rootBundle.loadString("assets/web/block_foreign_iframes.js"),
      await rootBundle.loadString("assets/web/block_href_swap.js"),
      await rootBundle.loadString("assets/web/web_interceptor.js"),
    ];
    var hoster = getHoster();
    controller.loadRequest(Uri.parse(rawLink));
    controller.addJavaScriptChannel("Print",
        onMessageReceived: (JavaScriptMessage message) {
      print("JS Message: ${message.message}");
      if (message.message.contains("[cookies]")) {
        cookies = message.message.replaceFirst("[cookies]", "");
        print("Extracted cookies: $cookies");
      }
      if (message.message.contains("[captured-url]")) {
        var url = message.message.replaceFirst("[captured-url]", "");
        if (hoster != null && hoster.isValidDirectDownloadUrl(url) == true) {
          handleFulfill(url);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Toolbar(
        settings: ToolbarSettings(
            title: "Follow the manual steps to successfully extract the link"),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
