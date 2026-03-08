import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/services/settings_service.dart';

class RomDownloadSourcesDialogConfirmDialogHintContent extends StatefulWidget {
  const RomDownloadSourcesDialogConfirmDialogHintContent({super.key});

  @override
  State<RomDownloadSourcesDialogConfirmDialogHintContent> createState() =>
      _RomDownloadSourcesDialogConfirmDialogHintContentState();
}

class _RomDownloadSourcesDialogConfirmDialogHintContentState
    extends State<RomDownloadSourcesDialogConfirmDialogHintContent> {
  var dontShowHintDialogChecked = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          onTap: () {
            launchUrl(Uri.parse(AppConstants.manualExtractionGuideEntry));
          },
          title: Text("Know more"),
          trailing: Icon(Icons.open_in_new),
        ),
        CheckboxListTile(
          value: dontShowHintDialogChecked,
          onChanged: (checked) {
            if (checked == null) {
              return;
            }
            setState(() {
              dontShowHintDialogChecked = checked;
            });
            SettingsService()
                .set(SettingsKeys.SHOW_MANUAL_INTERACTION_HINT, !checked);
          },
          title: Text(
            "Don't show this again",
          ),
        ),
      ],
    );
  }
}
