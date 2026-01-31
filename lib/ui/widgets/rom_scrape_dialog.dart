import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/services/scrapers/metadata/constants/launchbox_consoles_mapping.dart';
import 'package:yamata_launcher/services/scrapers/metadata/launchbox_scraper.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class RomScrapeDialog extends StatefulWidget {
  final String query;
  Function(RomInfo info) onSelected;
  RomScrapeDialog({super.key, required this.query, required this.onSelected});
  static show(
      BuildContext context, String query, Function(RomInfo info) onSelected) {
    showDialog(
      context: context,
      builder: (context) =>
          RomScrapeDialog(query: query, onSelected: onSelected),
    );
  }

  @override
  State<RomScrapeDialog> createState() => _RomScrapeDialogState();
}

class _RomScrapeDialogState extends State<RomScrapeDialog> {
  var isLoading = false;
  var results = <RomInfo>[];

  _fetchResults() async {
    setState(() {
      isLoading = true;
    });
    var results = await LaunchboxScraper().search(widget.query);
    setState(() {
      this.results = results;
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  _buildContent() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return EmptyPlaceholder(
        icon: Icons.search_off,
        title: "No results found",
        description: "Try a different search term.",
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: results.map((rom) {
        return ListTile(
          leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: rom.portrait != null && rom.portrait!.isNotEmpty
                  ? Image.network(
                      rom.portrait!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey,
                      child: Icon(Icons.videogame_asset),
                    )),
          title: Text(rom.name),
          subtitle:
              Text(LAUNCHBOX_CONSOLES_MAPPING[rom.console] ?? rom.console),
          onTap: () {
            widget.onSelected(rom);
            Navigator.of(context).pop();
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Results for "${StringHelper.truncateWithEllipsis(widget.query, 23)}"',
        textWidthBasis: TextWidthBasis.parent,
      ),
      content: SingleChildScrollView(
          child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
        ),
        child: _buildContent(),
      )),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
      ],
    );
  }
}
