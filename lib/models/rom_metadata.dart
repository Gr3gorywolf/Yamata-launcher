import 'package:yamata_launcher/models/rom_info.dart';

enum RomMetadataLookups {
  CRC("crc"),
  SERIAL("serial"),
  EXEC_NAME("execs"),
  FILE_SIZE("size"),
  SLUG("libretro-by-slug");

  final String value;
  const RomMetadataLookups(this.value);
}

class RomMetadata {
  String name = "";
  String? region;
  String? serial;
  RomInfo? info;
  String console = "";

  RomMetadata(
      {required this.name,
      this.region,
      this.serial,
      this.info,
      required this.console});

  RomMetadata.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    region = json['region'];
    serial = json['serial'];
    info = json['info'] != null ? RomInfo.fromJson(json['info']) : null;
    console = json['console'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['region'] = this.region;
    data['serial'] = this.serial;
    if (this.info != null) {
      data['info'] = this.info!.toJson();
    }
    data['console'] = this.console;
    return data;
  }
}
