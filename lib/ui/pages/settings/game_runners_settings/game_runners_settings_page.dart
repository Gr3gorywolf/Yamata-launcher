import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/ui/pages/settings/game_runners_settings/runner_settings_page.dart';

class GameRunnersSettingsPage extends StatefulWidget {
  const GameRunnersSettingsPage({super.key});

  @override
  State<GameRunnersSettingsPage> createState() =>
      _GameRunnersSettingsPageState();
}

class _GameRunnersSettingsPageState extends State<GameRunnersSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Runners')),
      body: ListView(
        children: EmulatorService.runners
            .where((runner) => runner.isSupportedOnCurrentPlatform)
            .map((runner) => _RunnerTile(
                  runner: runner,
                  onSettingsChanged: () => setState(() {}),
                ))
            .toList(),
      ),
    );
  }
}

class _RunnerTile extends StatelessWidget {
  final GameRunner runner;
  final VoidCallback onSettingsChanged;

  const _RunnerTile({
    required this.runner,
    required this.onSettingsChanged,
  });

  Future<void> _openRunner(BuildContext context) async {
    try {
      await runner.openRunner();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${runner.name}: $error')),
      );
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunnerSettings(runner: runner),
      ),
    );
    onSettingsChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.rocket_launch),
      title: Text(runner.name),
      subtitle: Text(runner.executablePath),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Open runner',
            icon: const Icon(Icons.play_arrow),
            onPressed:
                runner.isRunnerInstalled ? () => _openRunner(context) : null,
          ),
          IconButton(
            tooltip: 'Setup runner',
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
    );
  }
}
