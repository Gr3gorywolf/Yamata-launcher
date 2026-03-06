import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_plugin.dart';

import 'package:webview_cef/webview_cef.dart' as cef;
import 'package:webview_cef/src/webview_inject_user_script.dart';

import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
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

  WebViewController? controller;
  cef.WebViewController? cefController;

  String getDomain(String url) {
    try {
      return Uri.parse(url).host;
    } catch (e) {
      return "";
    }
  }

  WebViewController getWebViewController() {
    if (Platform.isWindows) {
      var params = WindowsWebViewControllerCreationParams(
          userDataFolder: FileSystemService.webviewCachePath);
      return WebViewController.fromPlatformCreationParams(params);
    }
    return WebViewController();
  }

  void handleFulfill(String url) {
    var fullUrl =
        "${url}||headers:User-Agent:${CommonHosterUtils().hosterUserAgent}^Referer:$rawLink";

    if (cookies.isNotEmpty) {
      fullUrl += "^Cookie: $cookies";
    }

    context.pop(fullUrl);
  }

  Future<void> initializeScripts() async {
    scriptsToRun = [
      await rootBundle.loadString("assets/web/block_foreign_iframes.js"),
      await rootBundle.loadString("assets/web/block_href_swap.js"),
      await rootBundle.loadString("assets/web/web_interceptor.js"),
    ];
  }

  Future<void> initializeWebviewFlutter() async {
    controller = getWebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (UrlChange url) {
            var hoster = getHoster();
            if (hoster != null &&
                hoster.isValidDirectDownloadUrl(url.url ?? "") == true) {
              handleFulfill(url.url ?? "");
            }
          },
          onPageStarted: (String url) async {
            await clearAds();
            await controller!.runJavaScript(
              getResourceLoadingBlockerScript(WebviewService.blockingRules),
            );
          },
          onPageFinished: (String url) async {
            await clearAds();
          },
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

    controller!.addJavaScriptChannel("Print",
        onMessageReceived: (JavaScriptMessage message) {
      if (message.message.contains("[cookies]")) {
        cookies = message.message.replaceFirst("[cookies]", "");
      }

      if (message.message.contains("[captured-url]")) {
        var url = message.message.replaceFirst("[captured-url]", "");
        var hoster = getHoster();

        if (hoster != null && hoster.isValidDirectDownloadUrl(url) == true) {
          handleFulfill(url);
        }
      }
    });

    controller!.loadRequest(Uri.parse(rawLink));
  }

  Future<void> initializeCef() async {
    await cef.WebviewManager()
        .initialize(userAgent: CommonHosterUtils().hosterUserAgent);

    var injectUserScripts = InjectUserScripts();

    for (var script in scriptsToRun) {
      injectUserScripts.add(UserScript(script, ScriptInjectTime.LOAD_START));
    }

    cefController = cef.WebviewManager().createWebView(
      loading: const Center(child: CircularProgressIndicator()),
      injectUserScripts: injectUserScripts,
    );

    cefController!.setWebviewListener(cef.WebviewEventsListener(
      onUrlChanged: (url) {
        var hoster = getHoster();

        if (hoster != null && hoster.isValidDirectDownloadUrl(url) == true) {
          handleFulfill(url);
        }
      },
      onLoadStart: (controller, url) {},
      onLoadEnd: (controller, url) {},
    ));

    final Set<cef.JavascriptChannel> jsChannels = {
      cef.JavascriptChannel(
          name: 'Print',
          onMessageReceived: (cef.JavascriptMessage message) {
            if (message.message.contains("[cookies]")) {
              cookies = message.message.replaceFirst("[cookies]", "");
            }

            if (message.message.contains("[captured-url]")) {
              var url = message.message.replaceFirst("[captured-url]", "");
              var hoster = getHoster();

              if (hoster != null &&
                  hoster.isValidDirectDownloadUrl(url) == true) {
                handleFulfill(url);
              }
            }
          }),
    };

    cefController!.setJavaScriptChannels(jsChannels);

    await cefController!.initialize(rawLink);

    setState(() {});
  }

  Future<void> clearAds() async {
    if (!Platform.isLinux) {
      for (var script in scriptsToRun) {
        await controller?.runJavaScript(script);
      }
    }
  }

  @override
  void initState() {
    super.initState();

    initializeScripts().then((_) {
      if (Platform.isLinux) {
        initializeCef();
      } else {
        initializeWebviewFlutter();
      }
    });
  }

  @override
  void dispose() {
    if (Platform.isLinux) {
      cefController?.dispose();
      cef.WebviewManager().quit();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Toolbar(
        settings: ToolbarSettings(
            title: "Follow the manual steps to successfully extract the link"),
      ),
      body: Platform.isLinux
          ? (cefController == null
              ? const Center(child: CircularProgressIndicator())
              : ValueListenableBuilder(
                  valueListenable: cefController!,
                  builder: (context, value, child) {
                    return cefController!.value
                        ? cefController!.webviewWidget
                        : cefController!.loadingWidget;
                  }))
          : WebViewWidget(controller: controller!),
    );
  }
}
