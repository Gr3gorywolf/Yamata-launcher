import 'package:yamata_launcher/models/contracts/json_serializable.dart';

class EmulatorIntent implements JsonSerializable {
  String? uniqueId;
  String? package;
  String? activity;
  String? action;
  dynamic data;
  dynamic extras;
  String? type;
  String? category;
  bool? requireExtraction;
  String? acceptedFilenameRegex;

  EmulatorIntent(
      {this.uniqueId,
      this.package,
      this.activity,
      this.action,
      this.data,
      this.extras,
      this.type,
      this.category,
      this.requireExtraction,
      this.acceptedFilenameRegex});

  EmulatorIntent.fromJson(Map<String, dynamic> json) {
    uniqueId = json['uniqueId'];
    package = json['package'];
    activity = json['activity'];
    action = json['action'];
    data = json['data'];
    extras = json['extras'];
    type = json['type'];
    category = json['category'];
    requireExtraction = json['requireExtraction'];
    acceptedFilenameRegex = json['acceptedFilenameRegex'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['uniqueId'] = this.uniqueId;
    data['package'] = this.package;
    data['activity'] = this.activity;
    data['action'] = this.action;
    data['data'] = this.data;
    data['extras'] = this.extras;
    data['type'] = this.type;
    data['category'] = this.category;
    data['requireExtraction'] = this.requireExtraction;
    data['acceptedFilenameRegex'] = this.acceptedFilenameRegex;
    return data;
  }
}

class Intents implements JsonSerializable {
  String? package;
  String? activity;
  String? type;
  String? action;

  Intents({this.package, this.activity, this.type, this.action});

  Intents.fromJson(Map<String, dynamic> json) {
    package = json['package'];
    activity = json['activity'];
    type = json['type'];
    action = json['action'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['package'] = this.package;
    data['activity'] = this.activity;
    data['type'] = this.type;
    data['action'] = this.action;
    return data;
  }
}
