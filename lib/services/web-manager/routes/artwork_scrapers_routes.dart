import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:collection/collection.dart';
import 'package:yamata_launcher/services/artwork_scrapers_service.dart';
import 'package:yamata_launcher/services/web-manager/helpers/request_helper.dart';

void registerArtworkScraperRoutes(Alfred app) {
  app.get('/api/artwork-scrapers', (req, res) async {
    return Future.wait(
      ArtworkScrapersService.configurableScrapers
          .where((scraper) => scraper.requiresAuth)
          .map((scraper) async {
        final credentials =
            await ArtworkScrapersService.getCredentials(scraper) ?? "";

        return {
          'name': scraper.name,
          'settingKey': scraper.type.name,
          'icon': scraper.icon,
          'refUrl': scraper.refUrl,
          'configured': credentials.trim().isNotEmpty,
          'apiKey': credentials,
        };
      }),
    );
  });

  app.put('/api/artwork-scrapers', (req, res) async {
    final jsonBody = await readJsonBody(req);
    final settingKey = jsonBody['settingKey']?.toString().trim() ?? "";
    final apiKey = jsonBody['apiKey']?.toString().trim() ?? "";

    if (settingKey.isEmpty) {
      return errorResponse(res, 'Artwork scraper is required.');
    }

    if (apiKey.isEmpty) {
      return errorResponse(res, 'API key cannot be empty.');
    }

    final artworkScraper = ArtworkScrapersService.configurableScrapers
        .firstWhereOrNull((item) => item.type.name == settingKey);

    if (artworkScraper == null) {
      return errorResponse(
        res,
        'Artwork scraper not found.',
        statusCode: HttpStatus.notFound,
      );
    }

    final success = await ArtworkScrapersService.saveCredentials(
      artworkScraper,
      apiKey,
    );

    if (!success) {
      return errorResponse(
        res,
        'Failed to save artwork scraper credentials. Check the logs for more details.',
        statusCode: HttpStatus.internalServerError,
      );
    }

    return okResponse();
  });

  app.delete('/api/artwork-scrapers', (req, res) async {
    final settingKey = decodeBase64QueryParameter(req, 'settingKey');

    if (settingKey.isEmpty) {
      return errorResponse(res, 'Artwork scraper is required.');
    }

    final artworkScraper = ArtworkScrapersService.configurableScrapers
        .firstWhereOrNull((item) => item.type.name == settingKey);

    if (artworkScraper == null) {
      return errorResponse(
        res,
        'Artwork scraper not found.',
        statusCode: HttpStatus.notFound,
      );
    }

    await ArtworkScrapersService.removeCredentials(artworkScraper);
    return okResponse();
  });
}
