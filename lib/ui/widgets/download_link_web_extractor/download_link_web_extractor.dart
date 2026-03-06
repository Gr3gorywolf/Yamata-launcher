import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';

class DownloadLinkWebExtractor extends StatefulWidget {
  final String rawLink;

  const DownloadLinkWebExtractor({super.key, required this.rawLink});

  @override
  State<DownloadLinkWebExtractor> createState() =>
      _DownloadLinkWebExtractorState();
}

class _DownloadLinkWebExtractorState extends State<DownloadLinkWebExtractor> {
  String get rawLink => widget.rawLink;

  InAppWebViewController? controller;

  List<String> scriptsToRun = [];
  String cookies = "";

  Hoster? getHoster() {
    return DownloadSourcesRepository().getHosterForUrl(rawLink);
  }

  String getDomain(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return "";
    }
  }

  void handleFulfill(String url) {
    var fullUrl =
        "$url||headers:User-Agent:${CommonHosterUtils().hosterUserAgent}^Referer:$rawLink";

    if (cookies.isNotEmpty) {
      fullUrl += "^Cookie:$cookies";
    }

    context.pop(url);
  }

  Future<void> clearAds() async {
    if (controller == null) return;

    for (var script in scriptsToRun) {
      await controller!.evaluateJavascript(source: script);
    }
  }

  Future<void> initialize() async {
    scriptsToRun = [
      await rootBundle.loadString("assets/web/block_foreign_iframes.js"),
      await rootBundle.loadString("assets/web/block_href_swap.js"),
      await rootBundle.loadString("assets/web/web_interceptor.js"),
    ];
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  Widget build(BuildContext context) {
    final hoster = getHoster();

    return Scaffold(
      appBar: Toolbar(
        settings: ToolbarSettings(
            title: "Follow the manual steps to successfully extract the link"),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(rawLink)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
        onWebViewCreated: (c) async {
          controller = c;

          controller!.addJavaScriptHandler(
            handlerName: "Print",
            callback: (args) {
              final message = args.first.toString();

              print("JS Message: $message");

              if (message.contains("[cookies]")) {
                cookies = message.replaceFirst("[cookies]", "");
                print("Extracted cookies: $cookies");
              }

              if (message.contains("[captured-url]")) {
                var url = message.replaceFirst("[captured-url]", "");

                if (hoster != null &&
                    hoster.isValidDirectDownloadUrl(url) == true) {
                  handleFulfill(url);
                }
              }

              return null;
            },
          );
        },
        onLoadStart: (controller, url) async {
          print("Page started loading: $url");
          await clearAds();
        },
        onLoadStop: (controller, url) async {
          print("Page finished loading: $url");
          await clearAds();
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url.toString();
          final host = Uri.parse(rawLink).host;

          if (hoster != null && hoster.isValidDirectDownloadUrl(url) == true) {
            handleFulfill(url);
            return NavigationActionPolicy.CANCEL;
          }

          if (!Uri.parse(url).host.contains(host)) {
            return NavigationActionPolicy.CANCEL;
          }

          return NavigationActionPolicy.ALLOW;
        },
        onUpdateVisitedHistory: (controller, url, _) {
          if (url == null) return;

          if (hoster != null &&
              hoster.isValidDirectDownloadUrl(url.toString()) == true) {
            handleFulfill(url.toString());
          }
        },
      ),
    );
  }
}
