import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamata_launcher/models/artwork_scraper.dart';
import 'package:yamata_launcher/models/contracts/debrider.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/models/debrider_credentials.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/credentials_service.dart';
import 'package:yamata_launcher/services/debrider_service.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/utils/flatpak_utils.dart';

class ArtworkScraperSettingsPage extends StatefulWidget {
  const ArtworkScraperSettingsPage({super.key});

  @override
  State<ArtworkScraperSettingsPage> createState() =>
      _ArtworkScraperSettingsPageState();
}

class _ArtworkScraperSettingsPageState
    extends State<ArtworkScraperSettingsPage> {
  List<String> availableRunners = [];
  Map<String, String> artworkCredentials = {};
  List<ArtworkScraper> configurableScrapers = [
    ArtworkScraper(
        name: "Steam GridDB",
        requiresAuth: true,
        refUrl: "https://www.steamgriddb.com",
        icon: "https://avatars.githubusercontent.com/u/48405094",
        type: ArtworkProviders.SGDB),
  ];
  @override
  void initState() {
    super.initState();
    fetchDebriderCreds();
  }

  void fetchDebriderCreds() async {
    for (var debrider in configurableScrapers.where((s) => s.requiresAuth)) {
      var creds = await CredentialsService.getCredentials(debrider.type.name);
      if (creds != null) {
        artworkCredentials[debrider.type.name] = creds;
      }
    }
    setState(() {
      artworkCredentials;
    });
  }

  void handleDeleteCredentials(ArtworkScraper artworkScraper) {
    AlertsService.showAlert(context, "Delete credentials",
        "Are you sure you want to delete the credentials for ${artworkScraper.name}?",
        callback: () {
      CredentialsService.removeCredentials(artworkScraper.type.name);
      artworkCredentials.remove(artworkScraper.type.name);
      setState(() {});
    });
  }

  void handleSaveCredentials(
      ArtworkProviders artworkProvider, String credentials) {
    CredentialsService.saveCredentials(artworkProvider.name, credentials)
        .then((success) {
      if (success) {
        artworkCredentials[artworkProvider.name] = credentials;
        setState(() {});
      } else {
        AlertsService.showAlert(context, "Error",
            "Failed to save credentials for ${artworkProvider.name}");
      }
    });
  }

  // void handleConfigureScreenScraper() {
  //   var artworkScraper = ArtworkProviders.SCREENSCRAPER;
  //   var initialValue = artworkCredentials.containsKey(artworkScraper.name)
  //       ? artworkCredentials[artworkScraper.name]
  //       : "";
  //   var creds = {
  //     "username": "",
  //     "password": "",
  //   };

  //   if (initialValue != null && initialValue.isNotEmpty) {
  //     try {
  //       creds = Map<String, String>.from(jsonDecode(initialValue));
  //     } catch (e) {
  //       print("Error parsing ScreenScraper credentials: $e");
  //     }
  //   }
  //   var passwordController =
  //       TextEditingController(text: creds["password"] ?? "");
  //   AlertsService.showPrompt(
  //     context,
  //     "Enter your ScreenScraper credentials",
  //     inputPlaceholder: "Username",
  //     inputType: TextInputType.name,
  //     lines: 1,
  //     initialValue: creds["username"] ?? "",
  //     extraContent: TextField(
  //       controller: passwordController,
  //       keyboardType: TextInputType.visiblePassword,
  //       decoration: InputDecoration(
  //         hintText: "Password",
  //       ),
  //       obscureText: true,
  //       onChanged: (text) {
  //         passwordController.text = text;
  //       },
  //     ),
  //   ).then((value) {
  //     if (value != null) {
  //       var newCreds = {
  //         "username": value,
  //         "password": passwordController.text,
  //       };
  //       handleSaveCredentials(artworkScraper, jsonEncode(newCreds));
  //     }
  //   });
  // }

  void handleConfigureCredentials(ArtworkScraper artworkScraper) {
    // if (artworkScraper.type == ArtworkProviders.SCREENSCRAPER) {
    //   handleConfigureScreenScraper();
    //   return;
    // }
    var initialValue = artworkCredentials.containsKey(artworkScraper.type.name)
        ? artworkCredentials[artworkScraper.type.name]
        : "";
    AlertsService.showPrompt(context, "${artworkScraper.name} API Key",
            inputPlaceholder: "Enter your ${artworkScraper.name} API key here",
            inputType: TextInputType.multiline,
            lines: 4,
            initialValue: initialValue)
        .then((value) {
      if (value != null) {
        handleSaveCredentials(artworkScraper.type, value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artwork Scraper Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ...configurableScrapers.map((artworkScraper) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Image.network(
                    artworkScraper.icon,
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey,
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
                  title: Text(artworkScraper.name),
                  subtitle: Opacity(
                    opacity: 0.7,
                    child: Text(
                        artworkCredentials.containsKey(artworkScraper.type.name)
                            ? "Credentials Configured"
                            : "No credentials Configured"),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () {
                          launchUrl(Uri.parse(artworkScraper.refUrl ?? ""));
                        },
                      ),
                      SizedBox(width: 3),
                      if (artworkCredentials
                          .containsKey(artworkScraper.type.name))
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            handleDeleteCredentials(artworkScraper);
                          },
                        ),
                      SizedBox(width: 3),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          handleConfigureCredentials(artworkScraper);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList()
          ],
        ),
      ),
    );
  }
}
