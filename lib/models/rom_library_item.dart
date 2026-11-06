import 'package:yamata_launcher/models/contracts/json_serializable.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/runner_configuration.dart';

class RomLibraryItem extends JsonSerializable {
  RomInfo rom;
  bool isFavorite = false;
  double playTimeMins = 0.0;
  String? filePath;
  DateTime? addedAt;
  DateTime? lastPlayedAt;
  DateTime? downloadedAt;
  String? openParams;
  String? overrideEmulator;
  RunnerConfiguration? overrideRunnerConfig;
  bool ignoreDefaultRunnerConfig = false;
  bool? doesExists = false;
  DownloadSourceRom? manualDownload;
  bool isImported = false;
  RomLibraryItem(
      {required this.rom,
      this.isFavorite = false,
      this.playTimeMins = 0.0,
      this.filePath,
      this.addedAt,
      this.lastPlayedAt,
      this.doesExists,
      this.downloadedAt,
      this.openParams,
      this.overrideEmulator,
      this.overrideRunnerConfig,
      this.ignoreDefaultRunnerConfig = false,
      this.manualDownload,
      this.isImported = false});

  // implement copyWith method
  RomLibraryItem.fromJson(Map<String, dynamic> json)
      : rom = RomInfo.fromJson(json['rom']),
        isFavorite = json['isFavorite'] ?? false,
        playTimeMins = (json['playTimeMins'] ?? 0).toDouble(),
        filePath = json['filePath'],
        addedAt =
            json['addedAt'] != null ? DateTime.parse(json['addedAt']) : null,
        lastPlayedAt = json['lastPlayedAt'] != null
            ? DateTime.parse(json['lastPlayedAt'])
            : null,
        downloadedAt = json['downloadedAt'] != null
            ? DateTime.parse(json['downloadedAt'])
            : null,
        openParams = json['openParams'],
        overrideEmulator = json['overrideEmulator'],
        overrideRunnerConfig = json['overrideRunnerConfig'] is Map
            ? RunnerConfiguration.fromJson(
                Map<String, dynamic>.from(json['overrideRunnerConfig']))
            : null,
        ignoreDefaultRunnerConfig = json['ignoreDefaultRunnerConfig'] ?? false,
        isImported = json['isImported'] ?? false,
        manualDownload = json['manualDownload'] != null
            ? DownloadSourceRom.fromJson(json['manualDownload'])
            : null;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['rom'] = this.rom.toJson();
    data['isFavorite'] = this.isFavorite;
    data['playTimeMins'] = this.playTimeMins;
    data['filePath'] = this.filePath;
    data['addedAt'] = this.addedAt?.toIso8601String();
    data['lastPlayedAt'] = this.lastPlayedAt?.toIso8601String();
    data['downloadedAt'] = this.downloadedAt?.toIso8601String();
    data['openParams'] = this.openParams;
    data['overrideEmulator'] = this.overrideEmulator;
    if (this.overrideRunnerConfig != null) {
      data['overrideRunnerConfig'] = this.overrideRunnerConfig!.toJson();
    }
    data['ignoreDefaultRunnerConfig'] = this.ignoreDefaultRunnerConfig;
    data['isImported'] = this.isImported;
    if (this.manualDownload != null) {
      data['manualDownload'] = this.manualDownload!.toJson();
    }
    return data;
  }
}
