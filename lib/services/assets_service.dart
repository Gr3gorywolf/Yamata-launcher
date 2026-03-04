import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:yamata_launcher/services/console_service.dart';

class AssetsService {
  static Future<bool> assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (e) {
      return false;
    }
  }

  static getGif(String name, {double size = 24, double? width}) {
    var hasExtension = name.contains('.');
    return Image.asset(
      gaplessPlayback: true,
      "assets/gifs/$name${hasExtension ? '' : '.gif'}",
      height: size,
      width: width ?? size,
    );
  }

  static getImage(String name, {double size = 24, double? width}) {
    var hasExtension = name.contains('.');
    return Image.asset(
      "assets/images/$name${hasExtension ? '' : '.png'}",
      height: size,
      width: width ?? size,
    );
  }

  static getSvgImage(String name, {double size = 24, double? width}) {
    return SvgPicture.asset(
      "assets/svgs/$name.svg",
      semanticsLabel: 'Dart Logo',
      height: size,
      width: width ?? size,
      fit: BoxFit.contain,
    );
  }

  static Image getConsoleIcon(String name,
      {double size = 24, double? width = 24}) {
    final double finalWidth = width ?? size;
    final String? fallbackUrl =
        ConsoleService.getConsoleFromName(name)?.logoUrl;
    var assetName = "assets/icons/consoles/${name.toUpperCase()}.png";

    Widget errorIcon() => Icon(Icons.error, size: size);

    return Image.asset(
      assetName,
      height: size,
      width: finalWidth,
      errorBuilder: (_, __, ___) {
        if (fallbackUrl == null) return errorIcon();

        return Image.network(
          fallbackUrl,
          height: size,
          width: finalWidth,
          errorBuilder: (_, __, ___) => errorIcon(),
        );
      },
    );
  }
}
