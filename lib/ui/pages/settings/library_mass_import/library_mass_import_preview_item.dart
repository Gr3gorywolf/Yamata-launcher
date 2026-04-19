import 'package:yamata_launcher/models/rom_library_item.dart';

enum LibraryImportPreviewStatus {
  COMPLETE,
  PARTIAL,
  NONE,
}

class LibraryMassImportPreviewItem {
  final RomLibraryItem libraryItem;
  final List<String> sourceFiles;
  final bool isValid;
  final LibraryImportPreviewStatus matchStatus;
  final bool isScraped;

  const LibraryMassImportPreviewItem({
    required this.libraryItem,
    required this.sourceFiles,
    required this.isValid,
    required this.matchStatus,
    required this.isScraped,
  });

  // implement a copywith method
  LibraryMassImportPreviewItem copyWith({
    RomLibraryItem? libraryItem,
    List<String>? sourceFiles,
    LibraryImportPreviewStatus? matchStatus,
    String? description,
    String? confidenceLabel,
    bool? isValid,
    bool? isScraped,
  }) {
    return LibraryMassImportPreviewItem(
      libraryItem: libraryItem ?? this.libraryItem,
      sourceFiles: List<String>.from(sourceFiles ?? this.sourceFiles),
      matchStatus: matchStatus ?? this.matchStatus,
      isValid: isValid ?? this.isValid,
      isScraped: isScraped ?? this.isScraped,
    );
  }
}
