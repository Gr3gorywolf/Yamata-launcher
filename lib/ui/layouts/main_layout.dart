import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import '../../services/assets_service.dart';
import '../../utils/screen_helpers.dart';

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

class _MainLayoutState extends State<MainLayout> with TrayListener {
  int _locationToIndex(String location) {
    return MainLayout._routes.indexWhere((e) => location.startsWith(e));
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      var updateProvider = Provider.of<AppProvider>(context, listen: false);
      if (updateProvider.updateInfo != null) {
        AlertsService.showUpdateAppBanner(context);
      }
    });
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
        return Container(
            height: 35, width: 35, child: Center(child: Icon(icon)));
      }
      return Stack(children: [
        CircularProgressIndicator(strokeWidth: 1.3, value: percent / 100),
        Positioned(child: Icon(icon), top: 6, left: 6)
      ]);
    }

    Widget buildDesktopLayout() {
      return Row(
        children: [
          NavigationRail(
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
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(child: widget.child),
        ],
      );
    }

    return Scaffold(
      body: isSmallScreen ? widget.child : buildDesktopLayout(),
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
