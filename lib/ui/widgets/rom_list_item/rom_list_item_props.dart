import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/download_history_item.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';

class RomListItemStatus {
  final IconData icon;
  final String text;
  final Color color;

  const RomListItemStatus({
    required this.icon,
    required this.text,
    required this.color,
  });
}

class RomListItemDownloadStatus {
  final String? contentLabel;
  final String? statusText;
  final double? progressValue;

  const RomListItemDownloadStatus({
    required this.contentLabel,
    required this.statusText,
    required this.progressValue,
  });

  bool get hasContent => contentLabel != null;

  bool get hasProgress => progressValue != null;
}

class RomListItemProps {
  final RomInfo romItem;
  final DownloadHistoryItem? download;
  final RomLibraryItem? libraryDetails;
  final Widget thumbnail;
  final Widget gameplayThumbnail;
  final String focusId;
  final String subHeader;
  final String? consoleName;
  final RomListItemDownloadStatus? downloadStatus;
  final String? trailingLabel;
  final bool isUsingGamepad;
  final bool showActionButton;
  final bool showLibraryActions;
  final RomListItemStatus status;
  final VoidCallback onOpenDetails;

  const RomListItemProps({
    required this.romItem,
    required this.download,
    required this.libraryDetails,
    required this.thumbnail,
    required this.gameplayThumbnail,
    required this.focusId,
    required this.subHeader,
    required this.consoleName,
    required this.downloadStatus,
    required this.trailingLabel,
    required this.isUsingGamepad,
    required this.showActionButton,
    required this.showLibraryActions,
    required this.status,
    required this.onOpenDetails,
  });

  bool get hasDownloadInfo => downloadStatus?.hasContent == true;

  bool get hasDownloadProgress => downloadStatus?.hasProgress == true;

  bool get hasTrailingLabel => trailingLabel != null;
}
