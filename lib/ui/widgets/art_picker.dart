import 'package:flutter/material.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';

class ArtPicker extends StatefulWidget {
  final List<String> arts;
  final String? title;

  const ArtPicker({
    super.key,
    required this.arts,
    this.title,
  });

  static Future<String?> show(
    BuildContext context, {
    required List<String> arts,
    String? title,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => ArtPicker(
        arts: arts,
        title: title,
      ),
    );
  }

  @override
  State<ArtPicker> createState() => _ArtPickerState();
}

class _ArtPickerState extends State<ArtPicker> {
  String? selectedArt;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width < 900 ? size.width * 0.82 : 760.0;
    final dialogHeight = size.height < 760 ? size.height * 0.68 : 560.0;

    return AlertDialog(
      title: Text(widget.title ?? 'Pick art'),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: widget.arts.isEmpty ? _buildEmptyState() : _buildArtGrid(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: selectedArt == null
              ? null
              : () => Navigator.of(context).pop(selectedArt),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const EmptyPlaceholder(
      icon: Icons.image_not_supported,
      title: 'No art found',
      description: 'Try another search or art type.',
    );
  }

  Widget _buildArtGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnsCount = _columnsForWidth(constraints.maxWidth);
        final columns = List.generate(columnsCount, (_) => <String>[]);

        for (var index = 0; index < widget.arts.length; index++) {
          columns[index % columnsCount].add(widget.arts[index]);
        }

        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columns.map((columnArts) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: columnArts
                        .map(
                          (art) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ArtPickerTile(
                              url: art,
                              selected: selectedArt == art,
                              onTap: () {
                                setState(() {
                                  selectedArt = selectedArt == art ? null : art;
                                });
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  int _columnsForWidth(double width) {
    if (width >= 680) return 4;
    if (width >= 480) return 3;
    if (width >= 280) return 2;
    return 1;
  }
}

class _ArtPickerTile extends StatelessWidget {
  final String url;
  final bool selected;
  final VoidCallback onTap;

  const _ArtPickerTile({
    required this.url,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? selectedColor : theme.dividerColor,
              width: selected ? 3 : 0,
            ),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  url,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;

                    return const AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Center(
                        child: Icon(Icons.broken_image),
                      ),
                    );
                  },
                ),
              ),
              if (selected)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selectedColor.withOpacity(0.16),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: selected ? 1 : 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 18,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
