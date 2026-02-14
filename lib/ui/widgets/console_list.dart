import 'dart:math';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/console.dart';
import 'console_card.dart';

class ConsoleList extends StatefulWidget {
  final Function(Console) onConsoleSelected;
  final Console? selectedConsole;
  final List<Console> consoles;

  const ConsoleList({
    super.key,
    required this.onConsoleSelected,
    this.selectedConsole,
    required this.consoles,
  });

  @override
  State<ConsoleList> createState() => _ConsoleListState();
}

class _ConsoleListState extends State<ConsoleList> {
  Map<String, List<Console>> _groupByVendor(List<Console> consoles) {
    final Map<String, List<Console>> grouped = {};

    for (final console in consoles) {
      final vendor = console.vendor ?? 'Other';
      grouped.putIfAbsent(vendor, () => []).add(console);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return {
      for (final key in sortedKeys) key: grouped[key]!,
    };
  }

  @override
  Widget build(BuildContext context) {
    final groupedConsoles = _groupByVendor(widget.consoles);
    final axisCount = max(2, (MediaQuery.of(context).size.width / 220).floor());

    int globalIndex = 0;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: groupedConsoles.entries.map((entry) {
        final vendor = entry.key;
        final consoles = entry.value;

        final section = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                vendor,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: consoles.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: axisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final console = consoles[index];
                final animationIndex = globalIndex++;

                return FadeIn(
                  delay: Duration(milliseconds: 8 * animationIndex),
                  child: ConsoleCard(
                    console,
                    onTap: () => widget.onConsoleSelected(console),
                  ),
                );
              },
            ),
          ],
        );

        return section;
      }).toList(),
    );
  }
}
