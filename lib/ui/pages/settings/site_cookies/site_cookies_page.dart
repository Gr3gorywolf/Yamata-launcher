import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/models/site_cookies.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/cookies_service.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:yamata_launcher/ui/widgets/wrapped_link_text.dart';
import 'package:yamata_launcher/utils/url_helper.dart';

class SiteCookiesPage extends StatefulWidget {
  const SiteCookiesPage({super.key});

  @override
  State<SiteCookiesPage> createState() => _SiteCookiesPageState();
}

class _SiteCookiesPageState extends State<SiteCookiesPage> {
  List<String> _cookieSites = [];

  Future<void> _loadCookieSites() async {
    String sitesArray =
        await SettingsService().get<String>(SettingsKeys.COOKIE_SITE_URLS);

    var sitesList = jsonDecode(sitesArray ?? "[]");
    _cookieSites = List<String>.from(sitesList);
    setState(() {});
  }

  bool _siteExists(String site) {
    return _cookieSites.contains(site.trim());
  }

  void handleSetSite({String? existingSite}) async {
    var cookies = "";
    var headers = "";
    var site = existingSite ?? "";

    TextEditingController cookiesController = TextEditingController();
    TextEditingController headersController = TextEditingController();
    TextEditingController siteController =
        TextEditingController(text: existingSite ?? "");

    if (existingSite != null) {
      final existing = await CookiesService().getSiteCookies(existingSite);
      cookies = existing?.cookie ?? "";
      headers = existing?.headers ?? "";
      cookiesController.text = cookies;
      headersController.text = headers;
    }

    await AlertsService.showAlert(
      context,
      existingSite != null ? "Edit site cookies" : "Add site cookies",
      "",
      extraContent: Column(
        children: [
          WrappedLinkText(
            text:
                "We have created a guide to help you extract the cookies from your browser:",
            linkText: "Guide link",
            link: AppConstants.cookiesGuideEntry,
          ),
          const SizedBox(height: 10),
          DialogSectionItem(
            title: "Site URL",
            icon: Icons.web,
            actions: [],
            content: TextField(
              controller: siteController,
              decoration: const InputDecoration(
                hintText: "https://example.com",
              ),
              onChanged: (text) {
                site = UrlHelper.getSiteFromUrl(text);
              },
            ),
          ),
          const SizedBox(height: 10),
          DialogSectionItem(
            title: "Site Cookies",
            icon: Icons.cookie,
            actions: [],
            content: TextField(
              minLines: 3,
              maxLines: 5,
              controller: cookiesController,
              decoration: const InputDecoration(
                hintText: "key1=value1; key2=value2; ...",
              ),
              onChanged: (text) {
                cookies = text;
              },
            ),
          ),
          DialogSectionItem(
            title: "Site additional Http Headers (Optional)",
            icon: Icons.http,
            helperText: "header1:value1; header2:value2; ...",
            actions: [],
            content: TextField(
              minLines: 3,
              maxLines: 5,
              controller: headersController,
              decoration: const InputDecoration(
                hintText: "header1:value1; header2:value2; ...",
              ),
              onChanged: (text) {
                headers = text;
              },
            ),
          ),
        ],
      ),
      callback: () async {
        final normalizedSite = site.trim();

        if (normalizedSite.isEmpty) return;

        final exists = _siteExists(normalizedSite);

        if (exists && existingSite == null) {
          AlertsService.showErrorSnackbar("Site already exists.");
          return;
        }
        await CookiesService().saveSiteCookies(
          normalizedSite,
          SiteCookies(
            cookie: cookies,
            headers: headers,
          ),
        );

        if (!exists) {
          setState(() {
            _cookieSites.add(normalizedSite);
          });

          await SettingsService().set(
            SettingsKeys.COOKIE_SITE_URLS,
            jsonEncode(_cookieSites),
          );
        }

        AlertsService.showSnackbar(
          exists
              ? "Cookies updated successfully"
              : "Cookie site added successfully",
        );
      },
    );
  }

  void handleDeleteSite(String site) async {
    if (site == null || site.trim().isEmpty) {
      return;
    }
    setState(() {
      _cookieSites.remove(site.trim());
    });
    await SettingsService()
        .set(SettingsKeys.COOKIE_SITE_URLS, jsonEncode(_cookieSites));
    await CookiesService().removeSiteCookies(site.trim());
    AlertsService.showSnackbar("Cookie site deleted successfully");
  }

  @override
  void initState() {
    super.initState();
    _loadCookieSites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Cookies'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: handleSetSite,
        child: const Icon(Icons.add),
      ),
      body: _cookieSites.isEmpty
          ? EmptyPlaceholder(
              icon: Icons.cookie,
              title: "No cookie sites added yet",
              description: "Add a site to manage its cookies.",
              action: PlaceHolderAction(
                  label: "Add Site", onPressed: handleSetSite),
            )
          : ListView.builder(
              itemCount: _cookieSites.length,
              itemBuilder: (_, index) {
                final site = _cookieSites[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Icon(Icons.cloud_download),
                    title: Text(site),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => handleDeleteSite(site),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => handleSetSite(existingSite: site),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
