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

class AdBlockedWebView extends StatefulWidget {
  String rawLink;
  String title;
  // Callback that gets called when a URL changes. Provides the new URL and the current cookies. Should return true if the URL change should be processed, or false to ignore it.
  bool Function(String url, String siteCookies)? onUrlChanged;
  // Shows a checkmark in the app bar that allows the user to confirm the current URL as the final one. Calls onDone with the current URL and cookies when pressed.
  Function(String url, String siteCookies)? onDone;
  bool? preventOutsideRedirects;

  AdBlockedWebView(
      {super.key,
      required this.rawLink,
      required this.title,
      this.onUrlChanged,
      this.onDone,
      this.preventOutsideRedirects = true});

  @override
  State<AdBlockedWebView> createState() => _AdBlockedWebViewState();
}

class _AdBlockedWebViewState extends State<AdBlockedWebView> {
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

  late final WebViewController controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {},
        onUrlChange: (UrlChange url) {
          widget.onUrlChanged?.call(url.url ?? "", cookies);
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
          var shouldContinue =
              widget.onUrlChanged?.call(request.url, cookies) ?? true;
          if (!shouldContinue) {
            ;
            return NavigationDecision.prevent;
          }

          if (!Uri.parse(request.url).host.contains(host) &&
              widget.preventOutsideRedirects == true) {
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
    controller.loadRequest(Uri.parse(rawLink));
    controller.addJavaScriptChannel("Print",
        onMessageReceived: (JavaScriptMessage message) {
      //print("JS Message: ${message.message}");
      if (message.message.contains("[cookies]")) {
        cookies = message.message.replaceFirst("[cookies]", "");
        //print("Extracted cookies: $cookies");
      }
      if (message.message.contains("[captured-url]")) {
        var url = message.message.replaceFirst("[captured-url]", "");
        widget.onUrlChanged?.call(url, cookies);
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
        settings: ToolbarSettings(title: widget.title, disableSearch: true),
        actions: widget.onDone != null
            ? [
                IconButton(
                  icon: Icon(Icons.check),
                  onPressed: () {
                    controller.currentUrl().then((onValue) {
                      widget.onDone?.call(onValue ?? "", cookies);
                    });
                  },
                )
              ]
            : null,
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
