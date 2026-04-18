import 'package:flutter/material.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item_props.dart';

class RomListItemHeader extends StatelessWidget {
  final String title;
  final String? subHeader;
  final TextStyle? titleStyle;
  final int titleMaxLines;
  final int subHeaderMaxLines;
  final double titleRightInset;
  final double subHeaderRightInset;

  const RomListItemHeader({
    super.key,
    required this.title,
    this.subHeader,
    this.titleStyle,
    this.titleMaxLines = 2,
    this.subHeaderMaxLines = 1,
    this.titleRightInset = 0,
    this.subHeaderRightInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(right: titleRightInset),
          child: Text(
            title,
            maxLines: titleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
        ),
        if (subHeader != null) ...[
          const SizedBox(height: 3),
          Padding(
            padding: EdgeInsets.only(right: subHeaderRightInset),
            child: Opacity(
              opacity: 0.7,
              child: Text(
                subHeader ?? '',
                maxLines: subHeaderMaxLines,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ]
      ],
    );
  }
}

class RomListItemDownloadContent extends StatelessWidget {
  final RomListItemDownloadStatus? downloadStatus;

  const RomListItemDownloadContent({
    super.key,
    required this.downloadStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (downloadStatus?.hasContent != true) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(
              Icons.cloud_download,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Opacity(
                opacity: 0.7,
                child: Text(
                  downloadStatus?.contentLabel ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
      ],
    );
  }
}

class RomListItemDownloadProgress extends StatelessWidget {
  final RomListItemDownloadStatus? downloadStatus;

  const RomListItemDownloadProgress({
    super.key,
    required this.downloadStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (downloadStatus?.hasProgress != true) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          backgroundColor: Colors.grey[800],
          value: downloadStatus?.progressValue ?? 0,
        ),
        const SizedBox(height: 3),
        Opacity(
          opacity: 0.7,
          child: Text(
            downloadStatus?.statusText ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class RomListItemTrailingLabel extends StatelessWidget {
  final String? label;
  final TextStyle? style;

  const RomListItemTrailingLabel({
    super.key,
    required this.label,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return const SizedBox.shrink();
    }

    return Opacity(
      opacity: 0.7,
      child: Text(
        label ?? '',
        style: style ?? Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class RomListItemStatusInfo extends StatelessWidget {
  final RomListItemStatus status;

  const RomListItemStatusInfo({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: status.color,
          fontWeight: FontWeight.w500,
        );

    return Row(
      children: [
        Icon(status.icon, size: 14, color: status.color),
        const SizedBox(width: 4),
        Text(
          status.text,
          style: textStyle,
        ),
      ],
    );
  }
}
