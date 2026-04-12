import 'package:yamata_launcher/models/contracts/debrider.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';

class HosterInfo {
  String uri;
  String domain;
  bool isDirect;
  bool isTorrent;
  HosterMetadata? metadata;
  bool canExtractLink;

  HosterInfo(
      {required this.uri,
      required this.domain,
      this.metadata = const HosterMetadata(),
      required this.isTorrent,
      required this.isDirect,
      required this.canExtractLink});
}
