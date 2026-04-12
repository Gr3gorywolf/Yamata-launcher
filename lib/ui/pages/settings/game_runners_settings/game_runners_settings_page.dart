import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/utils/flatpak_utils.dart';

class GameRunnersSettingsPage extends StatefulWidget {
  const GameRunnersSettingsPage({super.key});

  @override
  State<GameRunnersSettingsPage> createState() =>
      _GameRunnersSettingsPageState();
}

class _GameRunnersSettingsPageState extends State<GameRunnersSettingsPage> {
  List<String> availableRunners = [];
  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Runners'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ...EmulatorService.runners.map((runner) {
              var isAvailable = availableRunners.contains(runner.name);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.rocket_launch),
                  title: const Text('Heroic Games Launcher'),
                  subtitle: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: isAvailable
                        ? [
                            TextButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.sync),
                              label: const Text('Sync library'),
                            ),
                          ]
                        : [
                            Opacity(
                                child: Text('Not available on this system'),
                                opacity: 0.6),
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
