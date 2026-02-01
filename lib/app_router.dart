import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/ui/pages/console_roms/console_roms_page.dart';
import 'package:yamata_launcher/ui/pages/explore/search_results/search_results_page.dart';
import 'package:yamata_launcher/ui/pages/settings/console_sources/console_sources_page.dart';
import 'package:yamata_launcher/ui/pages/settings/custom_paths/custom_paths_page.dart';
import 'package:yamata_launcher/ui/pages/settings/download_sources/download_sources_page.dart';
import 'package:yamata_launcher/ui/pages/settings/emulator_settings/emulator_settings_page.dart';
import 'package:yamata_launcher/ui/pages/splashcreen/splashcreen_page.dart';
import 'package:yamata_launcher/ui/widgets/keyboard_pop_wrapper.dart';

import 'ui/layouts/main_layout.dart';
import 'ui/pages/explore/explore_page.dart';
import 'ui/pages/library/library_page.dart';
import 'ui/pages/downloads/downloads_page.dart';
import 'ui/pages/settings/settings_page.dart';

BuildContext? get navigatorContext =>
    router.routerDelegate.navigatorKey.currentContext;

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    //Splashcreen
    GoRoute(
      path: '/splash',
      pageBuilder: (_, __) => NoTransitionPage(child: SplashcreenPage()),
    ),
    ShellRoute(
      builder: (context, state, child) {
        return KeyboardPopWrapper(child: MainLayout(child: child));
      },
      routes: [
        /// HOME
        GoRoute(
          path: '/explore',
          pageBuilder: (_, __) => NoTransitionPage(child: ExplorePage()),
          routes: [
            GoRoute(
              path: 'console-roms',
              builder: (context, state) =>
                  ConsoleRomsPage(state.extra as Console),
            ),
            GoRoute(
              path: 'search-results',
              builder: (context, state) =>
                  SearchResultsPage(state.extra as String),
            ),
          ],
        ),

        /// LIBRARY
        GoRoute(
          path: '/library',
          pageBuilder: (_, __) => NoTransitionPage(child: LibraryPage()),
        ),

        /// DOWNLOADS
        GoRoute(
          path: '/downloads',
          pageBuilder: (_, __) => NoTransitionPage(child: DownloadsPage()),
        ),

        /// SETTINGS
        GoRoute(
          path: '/settings',
          pageBuilder: (_, __) => NoTransitionPage(
            key: ValueKey(DateTime.now().millisecondsSinceEpoch),
            child: SettingsPage(),
          ),
          routes: [
            GoRoute(
              path: 'console-sources',
              builder: (context, state) => ConsoleSourcesPage(),
            ),
            GoRoute(
              path: 'download-sources',
              builder: (context, state) => DownloadSourcesPage(),
            ),
            GoRoute(
              path: 'emulator-settings',
              builder: (context, state) => EmulatorSettingsPage(),
            ),
            GoRoute(
              path: 'custom-download-paths',
              builder: (context, state) => CustomPathsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
