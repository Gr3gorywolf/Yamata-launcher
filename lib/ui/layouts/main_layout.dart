import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:yamata_launcher/app_keyboard_listener.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/services/notifications_service.dart';
import 'package:yamata_launcher/app_gamepad_listener.dart';
import 'package:yamata_launcher/ui/widgets/gamepad_hint/gamepad_button_glyph.dart';
import 'package:yamata_launcher/ui/widgets/gamepad_hint/gamepad_hint_bar.dart';
import 'package:yamata_launcher/ui/widgets/global_focus_highlight.dart';
import '../../services/assets_service.dart';
import '../../utils/screen_helpers.dart';

final GlobalKey<ScaffoldState> mainLayoutKey = GlobalKey<ScaffoldState>();

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  static const _routes = [
    '/explore',
    '/library',
    '/downloads',
    '/settings',
  ];

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with TrayListener, WidgetsBindingObserver {
  late final FocusScopeNode _navScopeNode;
  late final FocusScopeNode _contentScopeNode;
  Stream<bool?>? changeTabStream;
  Stream<String?>? urlIncomingStream;

  int _locationToIndex(String location) {
    return MainLayout._routes.indexWhere((e) => location.startsWith(e));
  }

  @override
  void initState() {
    super.initState();
    _navScopeNode = FocusScopeNode(debugLabel: 'NavScope');
    _contentScopeNode = FocusScopeNode(debugLabel: 'ContentScope');
    var appProvider = Provider.of<AppProvider>(context, listen: false);
    changeTabStream = appProvider.onChangeTab.stream;
    urlIncomingStream = appProvider.onUrlIncoming.stream;
    changeTabStream?.listen((event) {
      handleOnChangeTabs(event);
    });
    if (appProvider.incomingDownloadUrl != null) {
      handleDownloadUrlIncoming(appProvider.incomingDownloadUrl);
    }
    urlIncomingStream?.listen((url) {
      handleDownloadUrlIncoming(url);
    });
    WidgetsBinding.instance.addObserver(this);
  }

  void handleDownloadUrlIncoming(String? url) {
    if (url != null && url.isNotEmpty) {
      context.go('/downloads');
    }
  }

  @override
  void dispose() {
    _navScopeNode.dispose();
    _contentScopeNode.dispose();
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    changeTabStream = null;
    urlIncomingStream = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("State: $state");

    if (state == AppLifecycleState.paused) {
      print("App paused, pausing active downloads...");
      NotificationsService.closeOngoingNotifications();
    }
  }

  void handleOnChangeTabs(bool? next) {
    print("Changing tab, next: $next");
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);
    if (currentIndex == -1) return;
    final isForward = next == null || next == true;

    final nextIndex = isForward
        ? (currentIndex + 1) % MainLayout._routes.length
        : (currentIndex - 1 + MainLayout._routes.length) %
            MainLayout._routes.length;

    context.go(MainLayout._routes[nextIndex]);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);

    final isSmallScreen = ScreenHelpers.isSmallScreen(context);
    final isMediumScreen = ScreenHelpers.isMediumScreen(context);

    final totalDownloadPercent =
        Provider.of<DownloadProvider>(context).totalDownloadPercent;

    const navigationItems = [
      {'icon': Icons.explore, 'label': 'Explore'},
      {'icon': Icons.collections_bookmark, 'label': 'Library'},
      {'icon': Icons.download_sharp, 'label': 'Downloads', 'isDownload': true},
      {'icon': Icons.settings, 'label': 'Settings'},
    ];

    Widget getLogo() {
      if (isMediumScreen) {
        return AssetsService.getSvgImage("logo-orig", size: 70);
      } else {
        return Center(
          child: AssetsService.getSvgImage("logo-orig", size: 165, width: 200),
        );
      }
    }

    Widget buildIcon(dynamic navigationItem) {
      final icon = navigationItem['icon'] as IconData;
      final percent =
          navigationItem['isDownload'] == true && totalDownloadPercent > 0
              ? totalDownloadPercent
              : null;

      if (percent == null) {
        return SizedBox(
          height: 35,
          width: 35,
          child: Center(child: Icon(icon)),
        );
      }

      return Stack(
        children: [
          CircularProgressIndicator(strokeWidth: 1.3, value: percent / 100),
          const Positioned(top: 6, left: 6, child: Icon(Icons.download_sharp))
        ],
      );
    }

    Widget buildDesktopLayout() {
      return Row(
        children: [
          FocusScope(
            node: _navScopeNode,
            child: NavigationRail(
              selectedIndex: currentIndex,
              extended: !isMediumScreen,
              minExtendedWidth: 190,
              minWidth: 60,
              indicatorColor: Colors.transparent,
              selectedLabelTextStyle:
                  TextStyle(color: Theme.of(context).colorScheme.primary),
              selectedIconTheme:
                  IconThemeData(color: Theme.of(context).colorScheme.primary),
              leading: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: getLogo(),
              ),
              destinations: navigationItems
                  .map(
                    (item) => NavigationRailDestination(
                      icon: buildIcon(item),
                      label: Text(item['label'] as String),
                    ),
                  )
                  .toList(),
              onDestinationSelected: (index) {
                context.go(MainLayout._routes[index]);
              },
            ),
          ),
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: FocusScope(
              node: _contentScopeNode,
              child: widget.child,
            ),
          ),
        ],
      );
    }

    Widget buildGamepadGuide() {
      return Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          if (!appProvider.isUsingGamepad || !appProvider.showGamepadGuide)
            return const SizedBox.shrink();
          return FadeInUp(
            duration: const Duration(milliseconds: 300),
            child: GamepadHintBar(hints: [
              GamepadHint(glyph: GamepadGlyph.leftStick, label: "Move"),
              if (!Platform.isAndroid)
                GamepadHint(glyph: GamepadGlyph.rightStick, label: "Scroll"),
              GamepadHint(glyph: GamepadGlyph.b, label: "Back"),
              GamepadHint(glyph: GamepadGlyph.a, label: "Select"),
              GamepadHint(glyph: GamepadGlyph.lb, label: ""),
              GamepadHint(glyph: GamepadGlyph.rb, label: "Change tabs"),
            ]),
          );
        },
      );
    }

    // Global keyboard handler (desktop only)
    Widget DesktopLayoutWithScopes() {
      return AppKeyboardListener(
        navScropeNode: _navScopeNode,
        contentScopeNode: _contentScopeNode,
        child: AppGamepadListener(
          navScropeNode: _navScopeNode,
          contentScopeNode: _contentScopeNode,
          child: Stack(children: [buildDesktopLayout(), buildGamepadGuide()]),
        ),
      );
    }

    return Scaffold(
      key: mainLayoutKey,
      body: isSmallScreen
          ? AppKeyboardListener(
              child: AppGamepadListener(
                  child: Stack(children: [widget.child, buildGamepadGuide()])))
          : DesktopLayoutWithScopes(),
      bottomNavigationBar: isSmallScreen
          ? Container(
              padding: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: currentIndex,
                showUnselectedLabels: true,
                onTap: (index) {
                  context.go(MainLayout._routes[index]);
                },
                items: navigationItems
                    .map(
                      (item) => BottomNavigationBarItem(
                        icon: buildIcon(item),
                        label: item['label'] as String,
                      ),
                    )
                    .toList(),
              ),
            )
          : null,
    );
  }
}
