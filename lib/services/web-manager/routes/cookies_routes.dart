import 'dart:convert';
import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/models/site_cookies.dart';
import 'package:yamata_launcher/services/cookies_service.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/services/web-manager/helpers/request_helper.dart';
import 'package:yamata_launcher/utils/url_helper.dart';

void registerCookieRoutes(Alfred app) {
  app.get('/api/cookies', (req, res) async {
    final cookieSites = await CookiesService().getAllCookieSiteUrls();
    final cookies = await Future.wait(cookieSites.map((site) async {
      final siteCookies = await CookiesService().getSiteCookies(site);

      return {
        'site': site,
        'cookies': siteCookies?.cookie,
        'headers': siteCookies?.headers,
      };
    }));

    return cookies;
  });

  app.put('/api/cookies', (req, res) async {
    final jsonBody = await readJsonBody(req);
    final site = UrlHelper.getSiteFromUrl(jsonBody['site']?.toString() ?? "");
    final cookies = jsonBody['cookies']?.toString();
    final headers = jsonBody['headers']?.toString();

    if (site.trim().isEmpty) {
      return errorResponse(res, 'Site URL cannot be empty.');
    }

    final cookieSites = await CookiesService().getAllCookieSiteUrls();
    final alreadyExists = cookieSites.contains(site);
    final success = await CookiesService().saveSiteCookies(
      site,
      SiteCookies(
        cookie: cookies,
        headers: headers,
      ),
    );

    if (!success) {
      return errorResponse(
        res,
        'Failed to save site cookies. Check the logs for more details.',
        statusCode: HttpStatus.internalServerError,
      );
    }

    if (!alreadyExists) {
      cookieSites.add(site);
      await SettingsService().set(
        SettingsKeys.COOKIE_SITE_URLS,
        jsonEncode(cookieSites),
      );
    }

    return okResponse();
  });

  app.delete('/api/cookies', (req, res) async {
    final site =
        UrlHelper.getSiteFromUrl(decodeBase64QueryParameter(req, 'site'));

    if (site.trim().isEmpty) {
      return errorResponse(res, 'Site URL cannot be empty.');
    }

    final cookieSites = await CookiesService().getAllCookieSiteUrls();
    cookieSites.remove(site);

    await SettingsService().set(
      SettingsKeys.COOKIE_SITE_URLS,
      jsonEncode(cookieSites),
    );
    await CookiesService().removeSiteCookies(site);

    return okResponse();
  });
}
