import 'package:flutter/material.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/database/daos/emulator_settings_dao.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/ui/pages/settings/emulator_settings/emulator_settings_form.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:yamata_launcher/ui/widgets/gamepad_aware_floating_action_button.dart';

class EmulatorSettingsPage extends StatefulWidget {
  const EmulatorSettingsPage({super.key});

  @override
  State<EmulatorSettingsPage> createState() => _EmulatorSettingsPageState();
}

class _EmulatorSettingsPageState extends State<EmulatorSettingsPage> {
  List<EmulatorSetting> emulatorSettings = [];

  List<String> get existingConsoles {
    return emulatorSettings.map((e) => e.console).toList();
  }

  void loadEmulatorSettings() async {
    if (db == null) {
      return;
    }
    emulatorSettings = await EmulatorSettingsDao(db!).getAll();
    setState(() {});
  }

  void deleteEmulatorSetting(String slug) async {
    if (db == null) {
      return;
    }
    await EmulatorSettingsDao(db!).delete(slug);
    emulatorSettings =
        emulatorSettings.where((setting) => setting.console != slug).toList();
    setState(() {});
  }

  void handleAddEmulatorSetting() async {
    // Show add emulator setting form
    showDialog(
        context: context,
        builder: (ctx) {
          return EmulatorSettingsForm(
            existingConsoles: existingConsoles,
            onSubmit: (EmulatorSetting setting) async {
              if (db == null) {
                return;
              }
              await EmulatorSettingsDao(db!).insert(setting);
              emulatorSettings.add(setting);
              setState(() {});
            },
          );
        });
  }

  void handleEditEmulatorSetting(EmulatorSetting setting) async {
    // Show edit emulator setting form
    showDialog(
        context: context,
        builder: (ctx) {
          return EmulatorSettingsForm(
            existingConsoles: existingConsoles
                .where((slug) => slug != setting.console)
                .toList(),
            editingSetting: setting,
            onSubmit: (EmulatorSetting updatedSetting) async {
              if (db == null) {
                return;
              }
              await EmulatorSettingsDao(db!).update(updatedSetting);
              int index = emulatorSettings
                  .indexWhere((element) => element.console == setting.console);
              if (index != -1) {
                emulatorSettings[index] = updatedSetting;
                setState(() {});
              }
            },
          );
        });
  }

  @override
  void initState() {
    // TODO: implement initState
    loadEmulatorSettings();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emulator Settings'),
      ),
      floatingActionButton: !emulatorSettings.isEmpty
          ? GamepadAwareFloatingActionButton(
              icon: Icons.add,
              title: 'Add emulator setting',
              onPressed: handleAddEmulatorSetting,
            )
          : null,
      body: emulatorSettings.isEmpty
          ? EmptyPlaceholder(
              icon: Icons.videogame_asset,
              title: 'No emulator settings',
              description:
                  'You have not added any emulator settings yet. Set up an emulator to start playing games.',
              action: PlaceHolderAction(
                  label: 'Setup Emulator', onPressed: handleAddEmulatorSetting),
            )
          : ListView.builder(
              itemCount: emulatorSettings.length,
              itemBuilder: (context, index) {
                final setting = emulatorSettings[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(
                        ConsoleService.getConsoleFromName(setting.console)
                                ?.name ??
                            ""),
                    subtitle: Opacity(
                        opacity: 0.6,
                        child: Text(setting.emulatorBinary.isEmpty
                            ? "No binary set (Direct launch)"
                            : setting.emulatorBinary)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () =>
                              deleteEmulatorSetting(setting.console),
                        ),
                        SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => handleEditEmulatorSetting(setting),
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
