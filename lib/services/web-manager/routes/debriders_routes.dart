import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:collection/collection.dart';
import 'package:yamata_launcher/models/debrider_credentials.dart';
import 'package:yamata_launcher/services/debrider_service.dart';
import 'package:yamata_launcher/services/web-manager/helpers/request_helper.dart';

void registerDebriderRoutes(Alfred app) {
  app.get('/api/debriders', (req, res) async {
    return Future.wait(
      DebriderService.debriders.map((debrider) async {
        final credentials =
            await DebriderService.getDebriderCredentials(debrider);
        final apiKey = credentials?.apiKey ?? "";

        return {
          'name': debrider.name,
          'settingKey': debrider.settingKey,
          'apiKey': apiKey,
          'configured': apiKey.trim().isNotEmpty,
          'authenticated': await debrider.isAuthenticated(),
        };
      }),
    );
  });

  app.put('/api/debriders', (req, res) async {
    final jsonBody = await readJsonBody(req);
    final settingKey = jsonBody['settingKey']?.toString().trim() ?? "";
    final apiKey = jsonBody['apiKey']?.toString().trim() ?? "";

    if (settingKey.isEmpty) {
      return errorResponse(res, 'Debrid provider is required.');
    }

    if (apiKey.isEmpty) {
      return errorResponse(res, 'API key cannot be empty.');
    }

    final debrider = DebriderService.debriders
        .firstWhereOrNull((item) => item.settingKey == settingKey);

    if (debrider == null) {
      return errorResponse(
        res,
        'Debrid provider not found.',
        statusCode: HttpStatus.notFound,
      );
    }

    final success = await DebriderService.saveDebriderCredentials(
      debrider,
      DebriderCredentials(apiKey: apiKey),
    );

    if (!success) {
      return errorResponse(
        res,
        'Failed to save debrid credentials. Check the logs for more details.',
        statusCode: HttpStatus.internalServerError,
      );
    }

    return okResponse();
  });

  app.delete('/api/debriders', (req, res) async {
    final settingKey = decodeBase64QueryParameter(req, 'settingKey');

    if (settingKey.isEmpty) {
      return errorResponse(res, 'Debrid provider is required.');
    }

    final debrider = DebriderService.debriders
        .firstWhereOrNull((item) => item.settingKey == settingKey);

    if (debrider == null) {
      return errorResponse(
        res,
        'Debrid provider not found.',
        statusCode: HttpStatus.notFound,
      );
    }

    await DebriderService.removeDebriderCredentials(debrider);
    return okResponse();
  });
}
