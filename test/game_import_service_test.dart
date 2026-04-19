import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yamata_launcher/services/game_import_service.dart';

void main() {
  group('GameImportService', () {
    test('scanForGames reports progress as files are processed', () async {
      final tempDir =
          await Directory.systemTemp.createTemp('game_import_progress_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      File('${tempDir.path}/Castlevania - Aria of Sorrow.gba')
          .writeAsStringSync('a');
      Directory('${tempDir.path}/nested').createSync(recursive: true);
      File('${tempDir.path}/nested/Ridge Racer Type 4.chd')
          .writeAsStringSync('b');

      final progressPayloads = <GameImportProgressPayload>[];
      final scanPayloads = <GameImportScanCallbackPayload>[];

      await GameImportService().scanForGames(
        tempDir.path,
        scanPayloads.add,
        onProgress: progressPayloads.add,
      );

      expect(scanPayloads.length, 2);
      expect(progressPayloads.length, 3);

      expect(progressPayloads[0].totalFiles, 0);
      expect(progressPayloads[0].processedFiles, 0);

      expect(progressPayloads[1].totalFiles, 1);
      expect(progressPayloads[1].processedFiles, 1);

      expect(progressPayloads[2].totalFiles, 2);
      expect(progressPayloads[2].processedFiles, 2);
    });
  });
}
