import 'package:yamata_launcher/models/contracts/json_serializable.dart';

class Console implements JsonSerializable {
  Console(
      {this.name,
      this.altName,
      this.slug,
      this.fromExternalSource,
      this.description,
      this.vendor,
      this.logoUrl});
  String? name;
  String? slug;
  String? altName;
  String? vendor;
  String? description;
  String? logoUrl;
  bool? fromExternalSource;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'altName': altName,
      'slug': slug,
      'vendor': vendor,
      'fromExternalSource': fromExternalSource,
      'description': description,
      'logoUrl': logoUrl,
      'vendor': vendor,
    };
  }
}
