import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/main.dart';
import 'package:yamata_launcher/models/contracts/debrider.dart';
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/exceptions/download_require_manual_exception.dart';
import 'package:yamata_launcher/models/hoster_info.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/assets_service.dart';
import 'package:yamata_launcher/services/cookies_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/ui/widgets/download_link_web_extractor/download_link_web_extractor.dart';
import 'package:yamata_launcher/ui/widgets/download_link_web_extractor/download_link_web_extractor_external.dart';
import 'package:yamata_launcher/ui/widgets/rom_download_sources_dialog/rom_download_sources_dialog.dart';
import 'package:yamata_launcher/ui/widgets/rom_download_sources_dialog/rom_download_sources_dialog_confirm_dialog_hint_content.dart';
import 'package:yamata_launcher/ui/widgets/selectable_chips.dart';
import 'package:yamata_launcher/ui/widgets/status_tag.dart';
import 'package:yamata_launcher/ui/widgets/wrapped_link_text.dart';
import 'package:yamata_launcher/utils/http_helper.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:yamata_launcher/utils/url_helper.dart';

import '../../../services/debrider_service.dart';

class DownloadSourcesDialogConfirmDialog extends StatefulWidget {
  RomDownloadSourceItem item;

  DownloadSourcesDialogConfirmDialog({
    Key? key,
    required this.item,
  }) : super(key: key);

  @override
  State<DownloadSourcesDialogConfirmDialog> createState() =>
      _DownloadSourcesDialogConfirmDialogState();
}

class _DownloadSourcesDialogConfirmDialogState
    extends State<DownloadSourcesDialogConfirmDialog> {
  final validStatuses = [
    HosterStatus.Valid,
    HosterStatus.ValidWithDebridSupport,
    HosterStatus.UnverifiedWithDebridSupport,
    HosterStatus.NeedsManual,
  ];
  List<Debrider> authDebriders = [];
  List<HosterInfo> hosters = [];
  Debrider? selectedDebrider;
  HosterInfo? selectedHoster;
  bool autoselectFirstDebrider = false;
  bool isLoadingDirectLink = false;
  var extractAfterDownload = false;

  void updateHoster(HosterInfo updated) {
    var index = hosters.indexWhere((h) => h.uri == updated.uri);
    if (index != -1) {
      hosters[index] = updated;
      setState(() {});
    }
  }

  Future<HosterInfo> getHosterInfoFromUrl(String uri) async {
    var hosterName =
        DownloadSourcesRepository().getDownloadSourceUrlHosterName(uri);
    var isDirect = false;
    if (hosterName == null) {
      isDirect = await DownloadSourcesRepository().isDirectDownload(uri);
    }
    var isTorrent = await DownloadSourcesRepository().urlIsTorrent(uri);
    var domainName = hosterName ?? StringHelper.getDomainName(uri);
    var domain = isDirect ? "$domainName - Direct download " : domainName;

    HosterMetadata? hosterMetadata;

    if (hosterName != null && !isTorrent) {
      hosterMetadata =
          await DownloadSourcesRepository().extractHosterMetadata(uri);
    } else {
      hosterMetadata = HosterMetadata(
        status: isDirect || isTorrent
            ? HosterStatus.Valid
            : HosterStatus.Unsupported,
      );
    }
    var foundDebrider = DebriderService.getDebriderForUrl(uri);
    if (foundDebrider != null) {
      var status = validStatuses.contains(hosterMetadata.status)
          ? HosterStatus.ValidWithDebridSupport
          : hosterMetadata.status;
      if (hosterMetadata.status == HosterStatus.Unsupported) {
        status = HosterStatus.UnverifiedWithDebridSupport;
      }
      hosterMetadata = HosterMetadata(
        fileName: hosterMetadata.fileName,
        status: status,
      );
    }
    var hosterInfo = HosterInfo(
      uri: uri,
      domain: domain,
      isDirect: isDirect,
      metadata: hosterMetadata,
      isTorrent: isTorrent,
      canExtractLink:
          isDirect || hosterName != null || isTorrent || foundDebrider != null,
    );

    var foundHosterIndex = hosters.indexWhere((h) => h.uri == uri);
    if (foundHosterIndex != -1) {
      hosters[foundHosterIndex] = hosterInfo;
      hosters = getSortedHosters(hosters);
      if (mounted) setState(() {});
      return hosterInfo;
    }
    return hosterInfo;
  }

  List<HosterInfo> getHostersWithoutMetadata() {
    var romUris = widget.item.rom.uris ?? [];
    if (romUris.isEmpty) return [];
    return romUris.map((uri) {
      var hosterName =
          DownloadSourcesRepository().getDownloadSourceUrlHosterName(uri);
      return HosterInfo(
        uri: uri,
        domain: hosterName ?? StringHelper.getDomainName(uri),
        isDirect: false,
        metadata: HosterMetadata(status: HosterStatus.Unknown),
        isTorrent: false,
        canExtractLink: false,
      );
    }).toList();
  }

  Future<void> loadHosters() async {
    await fetchAuthentifiedDebriders();
    setState(() {
      hosters = getHostersWithoutMetadata();
    });
    final futures = (widget.item.rom.uris ?? []).map((uri) async {
      return await getHosterInfoFromUrl(uri);
    }).toList();

    await Future.wait(futures);
  }

  void handleOpenManualExtractionDialog(String link) async {
    var showDialog =
        await SettingsService().get(SettingsKeys.SHOW_MANUAL_INTERACTION_HINT);
    if (showDialog == false) {
      handleManualLinkExtraction(link);
      return;
    }
    AlertsService.showAlert(navigatorContext!, "Manual interaction required",
        "The selected download source has a captcha or a timers that requires manual interaction to retrieve the download link. Please follow the instructions in the opened web view to get the direct download link, This embedded browser its equipped with ad-blocking capabilities, you will need to trigger the download in order to retrieve the direct download link.",
        acceptTitle: "Continue",
        textColor: Colors.white,
        extraContent: RomDownloadSourcesDialogConfirmDialogHintContent(),
        onClose: () {}, callback: () {
      handleManualLinkExtraction(link);
    });
  }

  void handleSendResult(String link) {
    var isValidFileExtensions = [
      ...VALID_ROM_EXTENSIONS,
      ...VALID_COMPRESSED_EXTENSIONS
    ].any((ext) => link.toLowerCase().endsWith(".$ext"));
    var isLinkFileName =
        link.split('/').last.contains('.') && isValidFileExtensions;
    Navigator.pop<RomDownloadSourcesDialogResult>(
        context,
        RomDownloadSourcesDialogResult(
          rom: widget.item.rom.copyWith(
            fileName: isLinkFileName
                ? Uri.decodeComponent(link.split('/').last)
                : selectedHoster?.metadata?.fileName,
            uris: [link],
            extractableUrl: selectedHoster?.uri,
          ),
          extractAfterDownload: extractAfterDownload,
        ));
  }

  void handleManualLinkExtraction(String rawLink) async {
    var useBuiltIn =
        await SettingsService().get(SettingsKeys.USE_BUILT_IN_LINK_EXTRACTOR);
    var link = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => useBuiltIn && !Platform.isLinux
            ? DownloadLinkWebExtractor(rawLink: rawLink)
            : DownloadLinkWebExtractorExternal(rawLink: rawLink),
        fullscreenDialog: true,
      ),
    );
    print("Extracted link: $link");
    if (link == null || link.isEmpty) {
      Future.microtask(() {
        AlertsService.showErrorSnackbar(
            "Could not extract download link for ${widget.item.rom.title}");
      });
      return;
    }
    handleSendResult(link);
  }

  void handleDownload() async {
    var link = null;
    var sourceRomLink = selectedHoster!.uri;
    var isDirectDownload = selectedHoster!.isDirect;
    // If its a torrent or magnet
    if (selectedDebrider != null &&
        selectedDebrider!.canHandleUrl(sourceRomLink)) {
      setState(() {
        isLoadingDirectLink = true;
      });
      try {
        link = await selectedDebrider!.getDirectDownloadLink(sourceRomLink);
        if (link != null && link.isNotEmpty) {
          handleSendResult(link);
        }
      } catch (e) {
        setState(() {
          isLoadingDirectLink = false;
        });
        Future.microtask(() {
          AlertsService.showErrorSnackbar(
              "Failed to get direct download link from debrid service: $e");
        });
      }
      setState(() {
        isLoadingDirectLink = false;
      });
      return;
    }
    // if its a direct download from a http server
    if (isDirectDownload) {
      var siteCookies = await CookiesService()
          .getSiteCookies(UrlHelper.getSiteFromUrl(sourceRomLink));
      var headers = HttpHelper().parseHeaders(siteCookies?.headers ?? "");
      if (siteCookies?.cookie != null && siteCookies!.cookie!.isNotEmpty) {
        sourceRomLink = UrlHelper.appendHeadersToUrl(
            sourceRomLink, {"Cookie": siteCookies.cookie!, ...headers});
      }
      handleSendResult(sourceRomLink);
      return;
    }
    setState(() {
      isLoadingDirectLink = true;
    });
    // If its a hoster and needs extraction
    try {
      link = await DownloadSourcesRepository()
          .extractDirectDownloadUrl(sourceRomLink);
    } catch (e) {
      setState(() {
        isLoadingDirectLink = false;
      });
      if (e is DownloadRequireManualException) {
        handleOpenManualExtractionDialog(sourceRomLink);
        return;
      } else {
        Future.microtask(() {
          AlertsService.showErrorSnackbar(e.toString());
        });
        return;
      }
    } finally {
      setState(() {
        isLoadingDirectLink = false;
      });
    }

    if (link == null || link.isEmpty) {
      Future.microtask(() {
        AlertsService.showErrorSnackbar(
            "Could not extract download link for ${widget.item.rom.title}");
      });
      return;
    }
    handleSendResult(link);
  }

  void handleSelectSource(HosterInfo hoster) {
    setState(() {
      selectedHoster = hoster;
    });
    if (selectedDebrider != null &&
        !selectedDebrider!.canHandleUrl(hoster.uri)) {
      setState(() {
        selectedDebrider = null;
      });
    }
    if (selectedDebrider == null && autoselectFirstDebrider) {
      for (var debrider in authDebriders) {
        if (debrider.canHandleUrl(hoster.uri)) {
          setState(() {
            selectedDebrider = debrider;
          });
          break;
        }
      }
    }
  }

  List<HosterInfo> getSortedHosters(List<HosterInfo> hostersToSort) {
    final sorted = List<HosterInfo>.from(hostersToSort);
    sorted.sort((a, b) {
      if (a.canExtractLink && !b.canExtractLink) return -1;
      if (!a.canExtractLink && b.canExtractLink) return 1;
      if (validStatuses.contains(a.metadata?.status) &&
          !validStatuses.contains(b.metadata?.status)) return -1;
      if (!validStatuses.contains(a.metadata?.status) &&
          validStatuses.contains(b.metadata?.status)) return 1;
      return a.domain.compareTo(b.domain) + a.uri.compareTo(b.uri);
    });
    return sorted;
  }

  void handleSelectFirstValidSource() {
    Future.doWhile(() async {
      if (selectedHoster != null) return false;
      var validHoster = hosters
          .firstWhereOrNull((h) => validStatuses.contains(h.metadata?.status));
      if (validHoster != null) {
        handleSelectSource(validHoster);
        return false;
      }
      await Future.delayed(Duration(milliseconds: 50));
      return true;
    });
  }

  Future fetchAuthentifiedDebriders() async {
    var debriders = DebriderService.debriders;
    var authDebriders = <Debrider>[];
    for (var debrider in debriders) {
      if (await debrider.isAuthenticated()) {
        authDebriders.add(debrider);
      }
    }
    if (mounted)
      setState(() {
        this.authDebriders = authDebriders;
      });
  }

  @override
  void initState() {
    super.initState();
    SettingsService()
        .get<bool>(SettingsKeys.SELECT_FIRST_DEBRIDER)
        .then((value) {
      if (mounted)
        setState(() {
          autoselectFirstDebrider = value ?? false;
        });
    });
    loadHosters();
    handleSelectFirstValidSource();
    SettingsService().get(SettingsKeys.ENABLE_EXTRACTION).then((value) {
      if (mounted)
        setState(() {
          extractAfterDownload = value ?? false;
        });
    });
  }

  Widget buildStatusChip(HosterInfo item) {
    var text = "Loading";
    var type = StatusTagType.normal;
    var metadataStatus = item.metadata?.status;
    if (metadataStatus == null) {
      return Container();
    }
    switch (metadataStatus) {
      case HosterStatus.Invalid:
        text = "File not found or link is broken";
        type = StatusTagType.error;
        break;
      case HosterStatus.NeedsManual:
        text = "Needs Manual Interaction";
        type = StatusTagType.warning;
        break;
      case HosterStatus.ValidWithDebridSupport:
        text = "Valid and compatible with debrid services";
        type = StatusTagType.success;
        break;
      case HosterStatus.UnverifiedWithDebridSupport:
        text = "Unsupported but compatible with debrid services";
        type = StatusTagType.warning;
        break;
      case HosterStatus.Valid:
        text = "Compatible";
        type = StatusTagType.success;
        break;
      case HosterStatus.Unsupported:
        text = "Unsupported / Unreachable";
        type = StatusTagType.error;
        break;
      case HosterStatus.Unknown:
        text = "Loading";
        type = StatusTagType.normal;
        break;
    }
    return StatusTag(
      text: text,
      type: type,
      size: StatusTagSize.sm,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(10),
      title: Row(children: [
        Text("Hoster Selection"),
        IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        )
      ], mainAxisAlignment: MainAxisAlignment.spaceBetween),
      content: Container(
        width: 400,
        constraints:
            BoxConstraints(maxWidth: 600, maxHeight: 500, minWidth: 400),
        child: hosters.isEmpty
            ? const Center(
                heightFactor: 0.8,
                child: CircularProgressIndicator(),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.item.sourceDonationUrl != null)
                    WrappedLinkText(
                        text: "Support ${widget.item.sourceTitle} by",
                        linkText: "sending a donation",
                        link: widget.item.sourceDonationUrl!),
                  SizedBox(height: 5),
                  if (hosters
                      .where((HosterInfo hoster) =>
                          hoster.metadata?.status == HosterStatus.Unknown)
                      .isNotEmpty)
                    LinearProgressIndicator(
                      value: null,
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: hosters.length,
                      itemBuilder: (_, index) {
                        final item = hosters[index];
                        var isDisabled = [
                          HosterStatus.Invalid,
                          HosterStatus.Unsupported,
                          HosterStatus.Unknown
                        ].contains(item.metadata?.status);
                        return Card(
                          child: ListTile(
                            enabled: !isDisabled,
                            hoverColor: Colors.transparent,
                            leading: Radio(
                              value: selectedHoster?.uri == item.uri,
                              groupValue: true,
                              onChanged: isDisabled
                                  ? null
                                  : (changed) {
                                      handleSelectSource(item);
                                    },
                            ),
                            title: Text(
                              item.domain,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Opacity(
                              opacity: 0.7,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item.metadata?.fileName != null) ...[
                                      Text(
                                        item.metadata?.fileName ?? '',
                                        maxLines: 2,
                                        style: TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                    ],
                                    buildStatusChip(item),
                                  ],
                                ),
                              ),
                            ),
                            onTap: () {
                              handleSelectSource(item);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  if (authDebriders.isNotEmpty &&
                      DebriderService.getDebriderForUrl(
                              selectedHoster?.uri ?? '') !=
                          null) ...[
                    ListTile(
                      title: Text(
                        "Supported debrid services",
                      ),
                      subtitle: Container(
                        margin: const EdgeInsets.only(top: 8),
                        child: SelectableChips<Debrider>(
                          value: selectedDebrider,
                          allowDeselect: true, // opcional (como "no selection")
                          onChanged: (debrider) {
                            setState(() {
                              selectedDebrider = debrider;
                            });
                          },
                          options: authDebriders
                              .where((debrider) => debrider
                                  .canHandleUrl(selectedHoster?.uri ?? ''))
                              .map((debrider) {
                            return ChipOption<Debrider>(
                              label: debrider.name,
                              value: debrider,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  CheckboxListTile(
                    value: extractAfterDownload,
                    onChanged: (checked) => {
                      setState(() {
                        extractAfterDownload = checked ?? false;
                      })
                    },
                    title: Text("Extract contents after download"),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: selectedHoster == null || isLoadingDirectLink
                          ? null
                          : handleDownload,
                      label: Text(
                        isLoadingDirectLink ? "Loading..." : "Download now",
                      ),
                      icon: isLoadingDirectLink
                          ? Container(
                              child: CircularProgressIndicator(
                                color: const Color.fromARGB(71, 255, 255, 255),
                              ),
                              height: 16,
                              width: 16)
                          : Icon(Icons.download)),
                ],
              ),
      ),
    );
  }
}

class _Result {
  final DownloadSourceRom rom;
  final String? sourceTitle;

  _Result({
    required this.rom,
    required this.sourceTitle,
  });
}
