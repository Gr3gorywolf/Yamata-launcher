import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:collection/collection.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/web-manager/helpers/request_helper.dart';

void registerDownloadSourceRoutes(Alfred app) {
  app.get('/api/download-sources', (req, res) {
    final provider =
        Provider.of<DownloadSourcesProvider>(navigatorContext!, listen: false);

    return provider.downloadSources
        .map((source) => {
              'id': source.sourceInfo!.downloadUrl,
              'title': source.sourceInfo!.title,
              'type': source.sourceInfo!.type?.name,
              'games': source.downloads!.length,
            })
        .toList();
  });

  app.post('/api/download-sources', (req, res) async {
    final jsonBody = await readJsonBody(req);
    final url = jsonBody['url']?.toString() ?? "";
    final type = DownloadSourceType.values.firstWhere(
      (item) => item.name == jsonBody['type'],
    );

    try {
      await _addOrUpdateDownloadSource(url, type);
    } catch (error) {
      return errorResponse(
        res,
        error.toString(),
        statusCode: HttpStatus.internalServerError,
      );
    }

    return okResponse();
  });

  app.put('/api/download-sources', (req, res) async {
    final id = decodeBase64QueryParameter(req, 'id');
    final provider =
        Provider.of<DownloadSourcesProvider>(navigatorContext!, listen: false);
    final source = provider.downloadSources
        .firstWhereOrNull((item) => item.sourceInfo!.downloadUrl == id);

    try {
      if (source == null) {
        throw Exception("This source type does not support refreshing.");
      }

      await _addOrUpdateDownloadSource(
        source.sourceInfo!.downloadUrl!,
        source.sourceInfo!.type!,
      );
    } catch (error) {
      return errorResponse(
        res,
        error.toString(),
        statusCode: HttpStatus.internalServerError,
      );
    }

    return okResponse();
  });

  app.delete('/api/download-sources', (req, res) {
    final id = decodeBase64QueryParameter(req, 'id');
    final provider =
        Provider.of<DownloadSourcesProvider>(navigatorContext!, listen: false);
    final source = provider.downloadSources
        .firstWhere((item) => item.sourceInfo!.downloadUrl == id);

    provider.removeDownloadSource(source);
    return okResponse();
  });
}

Future<void> _addOrUpdateDownloadSource(
  String url,
  DownloadSourceType type,
) async {
  final source =
      await DownloadSourcesRepository().fetchDownloadSource(url, type);

  if (source == null) {
    throw Exception(
      "Failed to fetch download source, please check the URL and try again.",
    );
  }

  source.sourceInfo.downloadUrl = url;
  source.sourceInfo.type = type;

  final provider =
      Provider.of<DownloadSourcesProvider>(navigatorContext!, listen: false);
  final success = await provider.setDownloadSource(source);

  if (!success) {
    throw Exception("This source already exists.");
  }
}
