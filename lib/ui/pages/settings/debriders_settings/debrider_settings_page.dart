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
  }

  void fetchDebriderCreds() {
    for (var debrider in DebriderService.debriders) {
      DebriderService.getDebriderCredentials(debrider).then((creds) {
        if (creds != null) {
          debriderCredentials[debrider.name] = creds;
          setState(() {});
        }
      });
    }
  }

  void fetchAvailableRunners() async {
    var runners = EmulatorService.runners;
    await FlatpakUtils.getInstalledFlatpakAppIds();
    for (var runner in runners) {
      if (await runner.isRunnerAvailable) {
        availableRunners.add(runner.name);
      }
    }
    setState(() {});
  }

  void handleConfigureCredentials(Debrider debrider) {
    var initialValue = debriderCredentials.containsKey(debrider.name)
        ? debriderCredentials[debrider.name]!.apiKey
        : "";
    AlertsService.showPrompt(context, "Configure ${debrider.name} API Key",
            inputPlaceholder: "Enter your ${debrider.name} API key here",
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
                  leading: const Icon(Icons.double_arrow),
                  title: Text(debrider.name),
                  subtitle: Opacity(
                    opacity: 0.7,
                    child: Text(debriderCredentials.containsKey(debrider.name)
                        ? "Credentials Configured"
                        : "No credentials Configured"),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      handleConfigureCredentials(debrider);
                    },
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
