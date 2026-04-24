import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/repository/roms_repository.dart';
import 'package:yamata_launcher/ui/pages/rom_details_dialog/widgets/rom_details_bottom_sheet.dart';

class RomDetailsDialog extends StatefulWidget {
  static show(BuildContext context, RomInfo romItem) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => RomDetailsDialog(
              rom: romItem,
            ));
  }

  RomInfo rom;
  RomDetailsDialog({required this.rom});
  @override
  _RomDetailsDialogState createState() => _RomDetailsDialogState();
}

class _RomDetailsDialogState extends State<RomDetailsDialog> {
  @override
  Widget build(BuildContext context) {
    var screenHeight = MediaQuery.of(context).size.height;
    var isLargeHeight = screenHeight > 800;
    return DraggableScrollableSheet(
        initialChildSize: isLargeHeight ? 0.64 : 0.95,
        minChildSize: isLargeHeight ? 0.64 : 0.95,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                child: Column(children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(12),
                      child: RomDetailsBottomSheet(
                        widget.rom,
                      ),
                    ),
                  )
                ]),
              ));
        });
  }
}
