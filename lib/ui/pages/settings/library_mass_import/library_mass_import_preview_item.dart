import 'package:yamata_launcher/models/rom_library_item.dart';

class LibraryMassImportPreviewItem {
  final RomLibraryItem libraryItem;
  final List<String> sourceFiles;
  final String matchStatus;
  final String description;
  final String confidenceLabel;
  final bool isValid;
  final bool isScraped;

  const LibraryMassImportPreviewItem({
    required this.libraryItem,
    required this.sourceFiles,
    required this.matchStatus,
    required this.description,
    required this.confidenceLabel,
    required this.isValid,
    required this.isScraped,
  });

  // implement a copywith method
  LibraryMassImportPreviewItem copyWith({
    RomLibraryItem? libraryItem,
    List<String>? sourceFiles,
    String? matchStatus,
    String? description,
    String? confidenceLabel,
    bool? isValid,
    bool? isScraped,
  }) {
    return LibraryMassImportPreviewItem(
      libraryItem: libraryItem ?? this.libraryItem,
      sourceFiles: List<String>.from(sourceFiles ?? this.sourceFiles),
      matchStatus: matchStatus ?? this.matchStatus,
      description: description ?? this.description,
      confidenceLabel: confidenceLabel ?? this.confidenceLabel,
      isValid: isValid ?? this.isValid,
      isScraped: isScraped ?? this.isScraped,
    );
  }
}
