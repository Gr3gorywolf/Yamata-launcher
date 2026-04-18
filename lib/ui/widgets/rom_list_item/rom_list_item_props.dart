import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';

class RomListItemDownloadState {
  final bool hasCurrentDownload;
  final String? contentTitle;
  final bool isExtraContent;
  final String? statusText;
  final int? progressPercent;
  final bool isExtracting;

  const RomListItemDownloadState({
    required this.hasCurrentDownload,
    required this.contentTitle,
    required this.isExtraContent,
    required this.statusText,
    required this.progressPercent,
    required this.isExtracting,
  });

  factory RomListItemDownloadState.fromDownloadInfo(
      DownloadInfo? downloadInfo) {
    return RomListItemDownloadState(
      hasCurrentDownload: downloadInfo != null,
      contentTitle: downloadInfo?.contentTitle,
      isExtraContent: downloadInfo?.isExtraContent ?? false,
      statusText: downloadInfo?.downloadInfo,
      progressPercent: downloadInfo?.downloadPercent,
      isExtracting: downloadInfo?.isExtracting ?? false,
    );
  }

  @override
  int get hashCode => Object.hash(
        hasCurrentDownload,
        contentTitle,
        isExtraContent,
        statusText,
        progressPercent,
        isExtracting,
      );
}

class RomListItemLibraryState {
  final String? filePath;
  final bool? fileExists;
  final String lastPlayedLabel;

  const RomListItemLibraryState({
    required this.filePath,
    required this.fileExists,
    required this.lastPlayedLabel,
  });

  factory RomListItemLibraryState.fromLibraryItem({
    required RomLibraryItem? libraryItem,
    required String lastPlayedLabel,
  }) {
    return RomListItemLibraryState(
      filePath: libraryItem?.filePath,
      fileExists: libraryItem?.doesExists,
      lastPlayedLabel: lastPlayedLabel,
    );
  }
  @override
  int get hashCode => Object.hash(
        filePath,
        fileExists,
        lastPlayedLabel,
      );
}

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
  final Widget thumbnail;
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
    required this.thumbnail,
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
