import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/hltb.dart';
import 'package:yamata_launcher/models/launchbox.dart';
import 'package:yamata_launcher/models/tgdb.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/repository/rom_details_repository.dart';
import 'package:yamata_launcher/ui/widgets/Images_carousel.dart';
import 'package:yamata_launcher/ui/widgets/rom_action_button.dart';
import 'package:yamata_launcher/ui/widgets/rom_download_sources_dialog/rom_download_sources_dialog.dart';
import 'package:yamata_launcher/ui/widgets/rom_library_actions.dart';
import 'package:yamata_launcher/ui/widgets/rom_rating.dart';
import 'package:yamata_launcher/ui/widgets/rom_thumbnail.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/ui/widgets/download_spinner.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/download_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:toast/toast.dart';

class RomDetailsBottomSheet extends StatefulWidget {
  final RomInfo rom;
  const RomDetailsBottomSheet(this.rom, {Key? key}) : super(key: key);

  @override
  State<RomDetailsBottomSheet> createState() => _RomDetailsBottomSheetState();
}

class _RomDetailsBottomSheetState extends State<RomDetailsBottomSheet> {
  bool isFetchingHltbDetails = false;
  bool isFetchingLaunchboxDetails = false;
  HltbEntry? hltbInfo;
  LaunchboxRomDetails? launchboxInfo;

  @override
  void initState() {
    super.initState();
    compileDownloadSources();
    fetchHltbInfo();
    fetchLaunchbox();
  }

  void compileDownloadSources() {
    var sourcesProvider =
        Provider.of<DownloadSourcesProvider>(context, listen: false);
    var downloadSources = sourcesProvider.compileRomDownloadSources([
      widget.rom,
    ]);
  }

  void fetchHltbInfo() async {
    setState(() => isFetchingHltbDetails = true);
    final data = await RomDetailsRepository().fetchHltbData(widget.rom);
    if (mounted)
      setState(() {
        hltbInfo = data;
        isFetchingHltbDetails = false;
      });
  }

  void fetchLaunchbox() async {
    setState(() => isFetchingLaunchboxDetails = true);
    final data = await RomDetailsRepository().fetchLaunchboxDetails(widget.rom);
    if (mounted)
      setState(() {
        launchboxInfo = data;
        isFetchingLaunchboxDetails = false;
      });
  }

  String formatDuration(int? hours) {
    if (hours == null) return "--";
    return "${hours}h";
  }

  String get gameSummary {
    if (launchboxInfo == null) return "";
    var infos = [
      if (launchboxInfo?.maxPlayers != null)
        if (launchboxInfo?.esrb != null) "${launchboxInfo!.esrb}",
      "${launchboxInfo!.maxPlayers} Players",
      if (launchboxInfo?.cooperative == true) "Co-op",
      if (launchboxInfo?.genres != null && launchboxInfo!.genres!.isNotEmpty)
        "Genres: ${launchboxInfo!.genres!.join(", ")}",
    ];
    return infos
        .where((info) =>
            info.isNotEmpty && !info.contains("No information available"))
        .join(", ");
  }

  String get description {
    if (launchboxInfo?.description?.isNotEmpty == true) {
      return launchboxInfo?.description ?? "";
    }
    if (hltbInfo?.description.isNotEmpty == true) {
      return hltbInfo!.description;
    }
    return "No description available.";
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 500;

    final thumbnail = RomThumbnail(widget.rom);
    var gameplayThumbnail = RomThumbnail(
      widget.rom!,
      customUrl: widget.rom!.gameplayCovers != null &&
              widget.rom!.gameplayCovers!.isNotEmpty
          ? widget.rom!.gameplayCovers!.first
          : null,
      timeout: Duration(milliseconds: 60),
    );
    final provider = DownloadProvider.of(context);
    final libraryProvider = LibraryProvider.of(context);
    final downloadInfo = provider.getDownloadInfo(widget.rom);
    final downloadedRom = libraryProvider.getLibraryItem(widget.rom.slug);

    Widget detailsContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Badge(
          label: Text(
            ConsoleService.getConsoleFromName(widget.rom.console)?.name ??
                "Unknown Console",
            style: const TextStyle(color: Colors.black),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.rom.name,
          style: Theme.of(context).textTheme.headlineLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 10),
        Opacity(
          opacity: 0.7,
          child: Text(
            widget.rom.releaseDate?.isEmpty ?? true
                ? "---"
                : widget.rom.releaseDate!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 10),
        Skeletonizer(
          enabled: isFetchingHltbDetails,
          child: Opacity(
            opacity: 0.7,
            child: Text(
              "Main: ${formatDuration(hltbInfo?.gameplayMain)} | "
              "Sides: ${formatDuration(hltbInfo?.gameplayMainExtra)} | "
              "Completion: ${formatDuration(hltbInfo?.gameplayCompletionist)}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Skeletonizer(
          enabled: isFetchingLaunchboxDetails,
          child: Text(
            description,
            maxLines: 5,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 10),
        if (gameSummary.isNotEmpty)
          Skeletonizer(
            enabled: isFetchingLaunchboxDetails,
            child: Opacity(
              opacity: 0.5,
              child: Text(
                gameSummary,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        isSmallScreen
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Opacity(
                        opacity: 0.7,
                        child: SizedBox(
                          width: double.infinity,
                          height: 200,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: gameplayThumbnail,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        top: 0,
                        child: Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            child: ClipRRect(
                                child: thumbnail,
                                borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: RomRating(
                          rating: widget.rom.rating,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  detailsContent,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        width: 170,
                        height: 228,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: thumbnail,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: RomRating(
                          rating: widget.rom.rating,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: detailsContent),
                ],
              ),
        const SizedBox(height: 20),
        if (downloadInfo != null) ...[
          SizedBox(
            height: 5,
          ),
          Opacity(
            opacity: 0.7,
            child: Text(
              "(${downloadInfo.isExtraContent ? "Extra Content" : "Base Game"}) ${downloadInfo.contentTitle ?? ""}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          SizedBox(
            height: 7,
          ),
          LinearProgressIndicator(
            backgroundColor: Colors.grey[800],
            value: (downloadInfo.downloadPercent ?? 0) / 100,
          ),
          const SizedBox(height: 4),
          Opacity(
            opacity: 0.7,
            child: Text(
              downloadInfo.downloadInfo ?? "",
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            RomActionButton(
              widget.rom,
              size: RomActionButtonSize.medium,
            ),
            const SizedBox(width: 6),
            RomLibraryActions(
              rom: widget.rom,
              size: RomLibraryActionSize.large,
            ),
            const SizedBox(width: 12),
          ],
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: 0.7,
          child: Text(
            RomService.getLastPlayedLabel(downloadedRom),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
        const SizedBox(height: 16),
        Skeletonizer(
          enabled: isFetchingLaunchboxDetails,
          child: Text(
            "Screenshots",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 10),
        Skeletonizer(
          enabled: isFetchingLaunchboxDetails,
          child: ImagesCarousel(
            images: [
              if (isFetchingLaunchboxDetails)
                "https://placehold.co/600x400.png",
              ...(widget.rom.gameplayCovers ?? []),
              ...(launchboxInfo?.screenshots ?? []),
            ],
            height: 300,
          ),
        ),
      ],
    );
  }
}
