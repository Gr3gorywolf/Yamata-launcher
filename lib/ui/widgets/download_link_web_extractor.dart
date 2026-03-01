import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';

class DownloadLinkWebExtractor extends StatefulWidget {
  String rawLink;
  DownloadLinkWebExtractor({super.key, required this.rawLink});

  @override
  State<DownloadLinkWebExtractor> createState() =>
      _DownloadLinkWebExtractorState();
}

class _DownloadLinkWebExtractorState extends State<DownloadLinkWebExtractor> {
  Hoster getHoster() {
    return DownloadSourcesRepository().getHosterForUrl(widget.rawLink)!;
  }

  late final WebViewController controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {},
        onUrlChange: (UrlChange url) {
          var hoster = getHoster();
          if (hoster.isValidDirectDownloadUrl(url.url ?? "")) {
            context.pop(url.url);
          }
        },
        onPageStarted: (String url) {
          this.clearAds();
          print("Page started loading: $url");
        },
        onPageFinished: (String url) {
          print("Page finished loading: $url");
        },
        onHttpError: (HttpResponseError error) {},
        onWebResourceError: (WebResourceError error) {},
        onNavigationRequest: (NavigationRequest request) {
          var host = Uri.parse(widget.rawLink).host;
          var hoster = getHoster();
          if (hoster.isValidDirectDownloadUrl(request.url)) {
            context.pop(request.url);
            return NavigationDecision.prevent;
          }
          if (!Uri.parse(request.url).host.contains(host)) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    )
    ..loadRequest(Uri.parse(widget.rawLink));

  void clearAds() {
    controller.runJavaScript(r"""
// ==UserScript==
// @name         The Simplest Adblocker
// @namespace    https://kawamoto.no-ip.org/
// @version      1.1
// @description  Just removes all cross-origin and dynamically generated iframes.
// @author       Suguru Kawamoto
// @include      *
// @grant        none
// @updateURL    https://kawamoto.no-ip.org/misc/The%20Simplest%20Adblocker.user.js
// @downloadURL  https://kawamoto.no-ip.org/misc/The%20Simplest%20Adblocker.user.js
// ==/UserScript==

(function() {
    'use strict';

    // Your code here...
    let f = function(){
        Array.prototype.forEach.call(document.getElementsByTagName("iframe"), function(e){
            let s = getComputedStyle(e);
            if(s.display != "none" && s.visibility == "visible" && s.opacity > 0){
                if(!e.src){
                    while(e.contentWindow.document.firstChild){
                        e.contentWindow.document.removeChild(e.contentWindow.document.firstChild);
                    }
                }else if(new URL(e.src, location.href).hostname != document.domain){
                    e.src = "about:blank";
                }
            }
        });
    };
    new MutationObserver(f).observe(document, {subtree : true, childList : true});
    f();
})();
      """);
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
