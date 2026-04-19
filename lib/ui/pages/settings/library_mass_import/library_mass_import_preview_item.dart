import 'package:yamata_launcher/models/rom_library_item.dart';

class LibraryMassImportPreviewItem {
  final RomLibraryItem libraryItem;
  final String sourceFile;
  final String matchStatus;
  final String description;
  final String confidenceLabel;
  final bool isValid;
  final bool isScraped;

  const LibraryMassImportPreviewItem({
    required this.libraryItem,
    required this.sourceFile,
    required this.matchStatus,
    required this.description,
    required this.confidenceLabel,
    required this.isValid,
    required this.isScraped,
  });

  // implement a copywith method
  LibraryMassImportPreviewItem copyWith({
    RomLibraryItem? libraryItem,
    String? sourceFile,
    String? matchStatus,
    String? description,
    String? confidenceLabel,
    bool? isValid,
    bool? isScraped,
  }) {
    return LibraryMassImportPreviewItem(
      libraryItem: libraryItem ?? this.libraryItem,
      sourceFile: sourceFile ?? this.sourceFile,
      matchStatus: matchStatus ?? this.matchStatus,
      description: description ?? this.description,
      confidenceLabel: confidenceLabel ?? this.confidenceLabel,
      isValid: isValid ?? this.isValid,
      isScraped: isScraped ?? this.isScraped,
    );
  }
}
