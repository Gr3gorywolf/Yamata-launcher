import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/contracts/debrider.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/models/debrider_credentials.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/debrider_service.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/utils/flatpak_utils.dart';

class DebriderSettingsPage extends StatefulWidget {
  const DebriderSettingsPage({super.key});

  @override
  State<DebriderSettingsPage> createState() => _DebriderSettingsPageState();
}

class _DebriderSettingsPageState extends State<DebriderSettingsPage> {
  List<String> availableRunners = [];
  Map<String, DebriderCredentials> debriderCredentials = {};
  @override
  void initState() {
    super.initState();
    fetchDebriderCreds();
  }

  void fetchDebriderCreds() async {
    for (var debrider in DebriderService.debriders) {
      var creds = await DebriderService.getDebriderCredentials(debrider);
      if (creds != null) {
        debriderCredentials[debrider.name] = creds;
      }
    }
    setState(() {
      debriderCredentials;
    });
  }

  void handleDeleteCredentials(Debrider debrider) {
    AlertsService.showAlert(context, "Delete credentials",
        "Are you sure you want to delete the credentials for ${debrider.name}?",
        callback: () {
      DebriderService.removeDebriderCredentials(debrider);
      debriderCredentials.remove(debrider.name);
      setState(() {});
    });
  }

  void handleConfigureCredentials(Debrider debrider) {
    var initialValue = debriderCredentials.containsKey(debrider.name)
        ? debriderCredentials[debrider.name]!.apiKey
        : "";
    AlertsService.showPrompt(context, "${debrider.name} API Key",
            inputPlaceholder: "Enter your ${debrider.name} API key here",
            inputType: TextInputType.multiline,
            lines: 4,
            initialValue: initialValue)
        .then((value) {
      if (value != null) {
        var creds = DebriderCredentials(apiKey: value);
        DebriderService.saveDebriderCredentials(debrider, creds)
            .then((success) {
          if (success) {
            debriderCredentials[debrider.name] = creds;
            setState(() {});
          } else {
            AlertsService.showAlert(context, "Error",
                "Failed to save credentials for ${debrider.name}");
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debrid services'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ...DebriderService.debriders.map((debrider) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.keyboard_double_arrow_down),
                  title: Text(debrider.name),
                  subtitle: Opacity(
                    opacity: 0.7,
                    child: Text(debriderCredentials.containsKey(debrider.name)
                        ? "Credentials Configured"
                        : "No credentials Configured"),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (debriderCredentials.containsKey(debrider.name))
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            handleDeleteCredentials(debrider);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          handleConfigureCredentials(debrider);
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
