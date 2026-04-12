import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:yamata_launcher/models/platform_catalog_source.dart';
import 'package:yamata_launcher/repository/platform_catalog_sources_repository.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/web-manager/helpers/request_helper.dart';

void registerPlatformCatalogRoutes(Alfred app) {
  app.get('/api/platform-catalogs', (req, res) {
    return ConsoleService.externalPlatformCatalogs
        .map((source) => {
              'id': source.downloadUrl,
              'name': source.sourceName,
              'platform': source.console.name,
            })
        .toList();
  });

  app.post('/api/platform-catalogs', (req, res) async {
    final jsonBody = await readJsonBody(req);
    final url = jsonBody['url']?.toString() ?? "";

    try {
      await _addOrUpdatePlatformCatalogSource(url, false);
    } catch (error) {
      return errorResponse(
        res,
        error.toString(),
        statusCode: HttpStatus.internalServerError,
      );
    }

    return okResponse();
  });

  app.put('/api/platform-catalogs', (req, res) async {
    final id = decodeBase64QueryParameter(req, 'id');

    try {
      await _addOrUpdatePlatformCatalogSource(id, true);
    } catch (error) {
      return errorResponse(
        res,
        error.toString(),
        statusCode: HttpStatus.internalServerError,
      );
    }

    return okResponse();
  });

  app.delete('/api/platform-catalogs', (req, res) {
    final id = decodeBase64QueryParameter(req, 'id');
    final source = ConsoleService.externalPlatformCatalogs
        .firstWhere((item) => item.downloadUrl == id);

    ConsoleService.deleteConsoleSource(source);
    return okResponse();
  });
}

Future<void> _addOrUpdatePlatformCatalogSource(
  String url,
  bool isUpdating,
) async {
  final source = await ConsoleSourcesRepository().fetchSource(url);

  if (source == null) {
    throw Exception(
      "Failed to fetch platform catalog source, please check the URL and try again.",
    );
  }

  source.downloadUrl = url;
  final validationError = ConsoleService.validatePlatformCatalogSource(source);
  if (validationError != null) {
    throw Exception(validationError);
  }

  if (isUpdating) {
    final updated = await ConsoleService.updateConsoleSource(source);
    if (!updated) {
      throw Exception("This source doesn't exist.");
    }
    return;
  }

  final added = await ConsoleService.addConsoleSource(source);
  if (!added) {
    throw Exception("This source already exists.");
  }
}
