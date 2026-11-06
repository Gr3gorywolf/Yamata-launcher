import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/services/emulator_service.dart';

class GameRunnersSettingsPage extends StatelessWidget {
  const GameRunnersSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Runners')),
      body: ListView(
        children: EmulatorService.runners
            .map((runner) => _RunnerTile(runner: runner))
            .toList(),
      ),
    );
  }
}

class _RunnerTile extends StatelessWidget {
  final GameRunner runner;

  const _RunnerTile({required this.runner});

  Future<void> _openSettings(BuildContext context) async {
    final settings = runner.buildRunnerSettings(context);
    if (settings == null) {
      try {
        await runner.openRunner();
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${runner.name}: $error')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('${runner.name} settings')),
          body: SafeArea(child: settings),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.rocket_launch),
      title: Text(runner.name),
      subtitle: Text(runner.executablePath),
      trailing: IconButton(
        tooltip: 'Configure runner',
        icon: const Icon(Icons.settings),
        onPressed: () => _openSettings(context),
      ),
    );
  }
}
