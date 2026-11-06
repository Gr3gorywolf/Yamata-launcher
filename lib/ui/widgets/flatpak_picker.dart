import 'package:flutter/material.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/utils/flatpak_utils.dart';

/// Selects an installed Flatpak and returns its application ID.
class FlatpakPicker extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const FlatpakPicker({super.key, required this.onSelected});

  Future<void> _pick(BuildContext context) async {
    final apps = (await FlatpakUtils.getInstalledFlatpakAppIds()).toList()
      ..sort();
    if (!context.mounted || apps.isEmpty) return;
    final selected = await AlertsService.showPicker(
      context,
      'Select a Flatpak',
      apps.map((app) => PickerOption(label: app, value: app)).toList(),
    );
    if (selected != null) onSelected(selected.value);
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => _pick(context),
        icon: const Icon(Icons.apps),
        label: const Text('Choose a Flatpak'),
      );
}
