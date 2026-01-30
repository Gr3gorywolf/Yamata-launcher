import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/ui/widgets/console_card.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/utils/filter_helpers.dart';

class ExplorePage extends StatefulWidget {
  @override
  ExplorePage_State createState() => ExplorePage_State();
}

class ExplorePage_State extends State<ExplorePage> {
  List<Console> _consoles = ConsoleService.getConsoles(unique: true)
    ..sort((a, b) => a.name?.compareTo(b.name ?? "") ?? 0);
  ToolbarValue<Console>? filterValues = null;

  var textController = TextEditingController();

  get filteredConsoles {
    if (filterValues == null) return _consoles;
    var newConsoles =
        FilterHelpers.handleDynamicFilter<Console>(_consoles, filterValues!);
    return newConsoles;
  }

  @override
  Widget build(BuildContext bldContext) {
    var axisCount = max(2, (MediaQuery.of(context).size.width / 220).floor());
    return Scaffold(
      appBar: Toolbar<Console>(
        settings: ToolbarSettings(title: "Explore", disableSearch: true),
        onChanged: (val) => {
          setState(() {
            filterValues = val;
          })
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textController,
                          decoration: const InputDecoration(
                            hintText: 'Search for roms',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (value) {
                            textController.clear();
                            context.push("/explore/search-results",
                                extra: value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Platforms",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final console = filteredConsoles[index];

                    // Usa tu ConsoleCard directamente
                    return ConsoleCard(
                      console,
                      onTap: () {
                        context.push("/explore/console-roms", extra: console);
                      },
                    );
                  },
                  childCount: filteredConsoles.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: axisCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
