import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/services/assets_service.dart';
import 'package:yamata_launcher/ui/widgets/focusable_element.dart';

class ConsoleCard extends StatelessWidget {
  Console console;
  int? romsCount;
  Function? onTap;
  ConsoleCard(this.console, {this.romsCount, this.onTap});
  @override
  Widget build(BuildContext context) {
    final focusId = "${console.vendor}_${console.slug}";

    return Card(
      /* decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(18)),
          border: Border.all(color: Colors.green, width: 1.5)),*/
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: FocusableElement(
        focusId: focusId,
        child: InkWell(
          canRequestFocus: false,
          borderRadius: BorderRadius.all(Radius.circular(8)),
          onTap: () {
            if (onTap != null) {
              onTap!();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AssetsService.getConsoleIcon(console.slug!,
                      size: 50, width: 110),
                  SizedBox(
                    height: 12,
                  ),
                  Text(
                    console.name!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  SizedBox(
                    height: 4,
                  ),
                  if (romsCount != null)
                    Text(
                      "${romsCount} roms",
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
