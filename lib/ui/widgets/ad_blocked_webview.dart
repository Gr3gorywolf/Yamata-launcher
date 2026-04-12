import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';

class AdBlockedWebView extends StatefulWidget {
  String rawLink;
  String title;
  bool Function(String url, String siteCookies, Map<String, String>? headers)?
      onUrlChanged;
  Function(String url, String siteCookies)? onDone;
  bool? preventOutsideRedirects;

  AdBlockedWebView({
    super.key,
    required this.rawLink,
    required this.title,
    this.onUrlChanged,
    this.onDone,
    this.preventOutsideRedirects = true,
  });

  @override
  State<AdBlockedWebView> createState() => _AdBlockedWebViewState();
}

class _AdBlockedWebViewState extends State<AdBlockedWebView> {
  InAppWebViewController? _controller;
  final List<UserScript> _initialUserScripts = [];
  bool _isLoadingScripts = true;
  String _cookies = "";

  String get rawLink => widget.rawLink;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final scripts = [
      await rootBundle.loadString("assets/web/block_foreign_iframes.js"),
      await rootBundle.loadString("assets/web/block_href_swap.js"),
      await rootBundle.loadString("assets/web/web_interceptor.js"),
    ];

    _initialUserScripts
      ..clear()
      ..addAll(
        scripts.map(
          (script) => UserScript(
            source: script,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            forMainFrameOnly: false,
          ),
        ),
      );

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingScripts = false;
    });
  }

  Future<void> _handleJavascriptMessage(dynamic payload) async {
    final message = payload?.toString() ?? "";
    if (message.startsWith("[cookies]")) {
      _cookies = message.replaceFirst("[cookies]", "").trim();
      return;
    }
  }

  void _registerJavascriptHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: "Print",
      callback: (args) {
        for (final arg in args) {
          _handleJavascriptMessage(arg);
        }
        return null;
      },
    );
  }

  bool _isOutsideRedirect(String url) {
    try {
      final requestedHost = Uri.parse(url).host;
      final originalHost = Uri.parse(rawLink).host;

      if (requestedHost.isEmpty || originalHost.isEmpty) {
        return false;
      }

      return !requestedHost.contains(originalHost);
    } catch (_) {
      return false;
    }
  }

  void _notifyUrlChanged(WebUri? url) {
    final value = url?.toString();
    if (value != null && value.isNotEmpty) {
      widget.onUrlChanged?.call(value, _cookies, null);
    }
  }

  Future<NavigationActionPolicy> _handleNavigation(
    NavigationAction navigationAction,
  ) async {
    final requestUrl = navigationAction.request.url?.toString() ?? "";

    final shouldContinue = widget.onUrlChanged
            ?.call(requestUrl, _cookies, navigationAction.request.headers) ??
        true;

    if (!shouldContinue) {
      return NavigationActionPolicy.CANCEL;
    }

    if (widget.preventOutsideRedirects == true &&
        (navigationAction.isRedirect == true ||
            navigationAction.isForMainFrame == true) &&
        _isOutsideRedirect(requestUrl)) {
      return NavigationActionPolicy.CANCEL;
    }

    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _handleDone() async {
    final currentUrl = await _controller?.getUrl();
    widget.onDone?.call(currentUrl?.toString() ?? "", _cookies);
  }

  @override
  void dispose() {
    _controller?.removeJavaScriptHandler(handlerName: "Print");
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Toolbar(
        settings: ToolbarSettings(title: widget.title, disableSearch: true),
        actions: widget.onDone != null
            ? [
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _handleDone,
                ),
              ]
            : null,
      ),
      body: _isLoadingScripts
          ? const Center(child: CircularProgressIndicator())
          : InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useShouldOverrideUrlLoading: true,
              ),
              initialUserScripts: UnmodifiableListView(_initialUserScripts),
              initialUrlRequest: URLRequest(url: WebUri(widget.rawLink)),
              onWebViewCreated: (controller) {
                _controller = controller;
                _registerJavascriptHandlers(controller);
              },
              onLoadStart: (controller, url) {
                _notifyUrlChanged(url);
              },
              onUpdateVisitedHistory: (controller, url, isReload) {
                _notifyUrlChanged(url);
              },
              onLoadStop: (controller, url) {
                _notifyUrlChanged(url);
              },
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.DENY,
                );
              },
              shouldOverrideUrlLoading: (controller, navigationAction) {
                return _handleNavigation(navigationAction);
              },
            ),
    );
  }
}
