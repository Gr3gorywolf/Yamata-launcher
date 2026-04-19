import 'package:yamata_launcher/models/contracts/json_serializable.dart';
import 'package:yamata_launcher/models/rom_info.dart';

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
  bool? doesExists = false;
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
        isImported = json['isImported'] ?? false;

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
    data['isImported'] = this.isImported;
    return data;
  }
}
