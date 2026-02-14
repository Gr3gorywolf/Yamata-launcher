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

  ToolbarValue<Console>? filterValues;
  var textController = TextEditingController();

  List<Console> get filteredConsoles {
    if (filterValues == null) return _consoles;
    return FilterHelpers.handleDynamicFilter<Console>(_consoles, filterValues!);
  }

  Map<String, List<Console>> _groupByVendor(
    List<Console> consoles, {
    List<String> priorityVendors = const [],
  }) {
    final Map<String, List<Console>> grouped = {};

    for (final console in consoles) {
      final vendor = console.vendor ?? 'Other';
      grouped.putIfAbsent(vendor, () => []).add(console);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    final priorityKeys =
        priorityVendors.where((vendor) => grouped.containsKey(vendor)).toList();
    final remainingKeys =
        sortedKeys.where((k) => !priorityKeys.contains(k)).toList();

    final orderedKeys = [...priorityKeys, ...remainingKeys];

    return {
      for (final key in orderedKeys) key: grouped[key]!,
    };
  }

  @override
  Widget build(BuildContext bldContext) {
    final axisCount = max(2, (MediaQuery.of(context).size.width / 220).floor());

    final grouped = _groupByVendor(filteredConsoles, priorityVendors: [
      "Nintendo",
      "Sony",
      "Microsoft",
      "Sega",
      "Atari",
      "Bandai",
    ]);

    return Scaffold(
      appBar: Toolbar<Console>(
        settings: ToolbarSettings(title: "Explore", disableSearch: true),
        onChanged: (val) {
          setState(() {
            filterValues = val;
          });
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

            // Vendor sections
            ...grouped.entries.expand((entry) {
              final vendor = entry.key;
              final consoles = entry.value;

              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      vendor,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final console = consoles[index];
                        return ConsoleCard(
                          console,
                          onTap: () {
                            context.push("/explore/console-roms",
                                extra: console);
                          },
                        );
                      },
                      childCount: consoles.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: axisCount,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                  ),
                ),
              ];
            }).toList(),
          ],
        ),
      ),
    );
  }
}
