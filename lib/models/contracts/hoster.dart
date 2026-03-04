import 'package:yamata_launcher/models/hoster_metadata.dart';

abstract class Hoster {
  String get name;
  Future<String?> extractDownloadUrl(String url);
  Future<HosterMetadata?> extractMetadata(String url);
  bool canHandleUrl(String url);
  bool isValidDirectDownloadUrl(String url);
}
