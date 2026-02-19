import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/ui/widgets/console_card.dart';
import 'package:yamata_launcher/utils/animation_helper.dart';
import 'package:yamata_launcher/services/assets_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:skeletonizer/skeletonizer.dart';

class RomThumbnail extends StatelessWidget {
  final RomInfo info;
  final double height;
  final double width;
  final String? customUrl;
  final Duration? timeout;

  const RomThumbnail(
    this.info, {
    super.key,
    this.height = 50,
    this.width = 50,
    this.customUrl,
    this.timeout,
  });

  @override
  Widget build(BuildContext context) {
    final url = customUrl ?? info.portrait;
    final slug = info.slug;

    final cachedFile = RomThumbnailCache.get(slug);

    if (cachedFile != null) {
      return Image.file(
        cachedFile,
        height: height,
        width: width,
        fit: BoxFit.cover,
        cacheWidth: width.toInt() * 3,
        cacheHeight: height.toInt() * 3,
        filterQuality: FilterQuality.low,
      );
    }

    if (url == null || url.isEmpty || !url.startsWith("http")) {
      return AssetsService.getConsoleIcon(
        info.console,
        size: width,
      );
    }

    return Image.network(
      url,
      height: height,
      width: width,
      fit: BoxFit.cover,
      cacheWidth: width.toInt() * 3,
      cacheHeight: height.toInt() * 3,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const _ThumbnailSkeleton();
      },
      errorBuilder: (context, error, stack) {
        return AssetsService.getConsoleIcon(
          info.console,
          size: width,
        );
      },
    );
  }
}

class _ThumbnailSkeleton extends StatelessWidget {
  const _ThumbnailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer.zone(
      enabled: true,
      child: const Bone(
        height: double.infinity,
        width: double.infinity,
      ),
    );
  }
}

class RomThumbnailCache {
  static final Map<String, File?> _cache = {};

  static File? get(String slug) {
    if (_cache.containsKey(slug)) return _cache[slug];

    final path = "${FileSystemService.portraitsPath}/$slug.png";
    final file = File(path);
    final exists = file.existsSync();

    _cache[slug] = exists ? file : null;
    return _cache[slug];
  }
}
