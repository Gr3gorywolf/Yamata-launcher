import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/native/intents_android_interface.dart';
import 'package:yamata_launcher/ui/widgets/download_list_item.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:yamata_launcher/ui/widgets/new_download_form.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  ToolbarValue? filterValues;

  @override
  void initState() {
    super.initState();
    Future.microtask(compileDownloadedRoms);
    handleIncomingDownloadUrl();
  }

  void handleIncomingDownloadUrl() {
    if (Platform.isAndroid) {
      IntentsAndroidInterface.getIncomingIntentUrl().then((url) {
        if (url != null && url.isNotEmpty) {
          openDownloadForm(url);
          Provider.of<AppProvider>(context, listen: false)
              .setIncomingDownloadUrl(null);
        }
      });
    }
  }

  void compileDownloadedRoms() {
    final libraryProvider =
        Provider.of<LibraryProvider>(context, listen: false);
    final downloadSourcesProvider =
        Provider.of<DownloadSourcesProvider>(context, listen: false);

    final downloads = libraryProvider.getDownloads();
    downloadSourcesProvider.compileRomDownloadSources(
      downloads.map((e) => e.rom).toList(),
    );
  }

  void openDownloadForm(String? url) {
    showDialog(
      context: context,
      builder: (_) => NewDownloadForm(
        initialUrl: url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Toolbar(
        onChanged: (values) {
          setState(() => filterValues = values);
        },
        initialValues: ToolbarValue(filters: [], search: ''),
        settings: ToolbarSettings(title: "Downloads", disableSearch: true),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openDownloadForm(null),
        icon: const Icon(Icons.add),
        label: const Text("Add download"),
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, downloadProvider, _) {
          final ongoingDownloads = downloadProvider.activeDownloadInfos
              .where((d) => d.romInfo != null && d.isPaused == false)
              .toList();

          final pausedDownloads = downloadProvider.activeDownloadInfos
              .where((d) => d.romInfo != null && d.isPaused == true)
              .toList();

          final completedDownloads = downloadProvider.downloadHistory
              .where((d) => d.romInfo != null)
              .map((d) => d)
              .toList();

          final hasAnything = ongoingDownloads.isNotEmpty ||
              pausedDownloads.isNotEmpty ||
              completedDownloads.isNotEmpty;

          if (!hasAnything) {
            return EmptyPlaceholder(
              icon: Icons.download,
              title: "No downloads yet",
              description:
                  "Games you download will appear here. Add download sources, then start exploring the library and find something to download.",
              action: PlaceHolderAction(
                label: "Go to catalog",
                onPressed: () => context.push('/explore'),
              ),
            );
          }

          return FadeIn(
            duration: const Duration(seconds: 1),
            child: CustomScrollView(
              slivers: [
                const SliverPadding(padding: EdgeInsets.only(top: 16)),

                // ongoing downloads
                if (ongoingDownloads.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        "Ongoing",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(top: 10)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final download = ongoingDownloads[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DownloadListItem(
                              romItem: download.romInfo!,
                              downloadInfo: download,
                              showConsole: true,
                            ),
                          );
                        },
                        childCount: ongoingDownloads.length,
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(top: 16)),
                ],
                // Paused downloads
                if (pausedDownloads.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        "Paused",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(top: 10)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final download = pausedDownloads[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DownloadListItem(
                              romItem: download.romInfo!,
                              downloadInfo: download,
                              showConsole: true,
                            ),
                          );
                        },
                        childCount: pausedDownloads.length,
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(top: 16)),
                ],

                // Completed downloads
                if (completedDownloads.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        "Completed",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(top: 10)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = completedDownloads[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DownloadListItem(
                              romItem: item.romInfo!,
                              downloadHistoryItem: item,
                              showConsole: true,
                            ),
                          );
                        },
                        childCount: completedDownloads.length,
                      ),
                    ),
                  ),
                ],

                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}
