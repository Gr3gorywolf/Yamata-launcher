import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:yamata_launcher/app_keyboard_listener.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/services/notifications_service.dart';
import 'package:yamata_launcher/ui/widgets/gamepad_handler.dart';
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

  int _locationToIndex(String location) {
    return MainLayout._routes.indexWhere((e) => location.startsWith(e));
  }

  @override
  void initState() {
    super.initState();
    _navScopeNode = FocusScopeNode(debugLabel: 'NavScope');
    _contentScopeNode = FocusScopeNode(debugLabel: 'ContentScope');
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _navScopeNode.dispose();
    _contentScopeNode.dispose();
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("State: $state");

    if (state == AppLifecycleState.paused) {
      print("App paused, pausing active downloads...");
      NotificationsService.closeOngoingNotifications();
    }
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

    // Global keyboard handler (desktop only)
    Widget desktopWithGlobalKeys() {
      return Focus(
        autofocus: true,
        canRequestFocus: false,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          final key = event.logicalKey;

          final isLeft = key == LogicalKeyboardKey.arrowLeft;
          final isRight = key == LogicalKeyboardKey.arrowRight;

          final isDown = key == LogicalKeyboardKey.arrowDown;

          if (isLeft) {
            final moved = FocusManager.instance.primaryFocus
                    ?.focusInDirection(TraversalDirection.left) ??
                false;

            if (!moved) {
              _navScopeNode.requestFocus();
            }

            return KeyEventResult.handled;
          }

          if (isRight) {
            final moved = FocusManager.instance.primaryFocus
                    ?.focusInDirection(TraversalDirection.right) ??
                false;

            if (!moved) {
              _contentScopeNode.requestFocus();
            }

            return KeyEventResult.handled;
          }

          if (isDown) {
            final moved = FocusManager.instance.primaryFocus
                    ?.focusInDirection(TraversalDirection.down) ??
                false;

            if (!moved) {
              _contentScopeNode.requestFocus();
            }

            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: GamepadHandler(
            child: buildDesktopLayout(),
            navScropeNode: _navScopeNode,
            contentScopeNode: _contentScopeNode),
      );
    }

    return Scaffold(
      key: mainLayoutKey,
      body: AppKeyboardListener(
        onChangeTab: (next) {
          if (currentIndex == -1) return;
          final isForward = next == null || next == true;

          final nextIndex = isForward
              ? (currentIndex + 1) % MainLayout._routes.length
              : (currentIndex - 1 + MainLayout._routes.length) %
                  MainLayout._routes.length;

          context.go(MainLayout._routes[nextIndex]);
        },
        child: isSmallScreen
            ? GamepadHandler(child: widget.child)
            : desktopWithGlobalKeys(),
      ),
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
