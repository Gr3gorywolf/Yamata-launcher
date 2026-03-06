import 'package:yamata_launcher/models/contracts/json_serializable.dart';

class RomInfo implements JsonSerializable {
  String slug = "";
  String? detailsUrl;
  String name = "";
  String? portrait;
  String? logo;
  String? rating;
  String? releaseDate;
  String? titleImage;
  List<String>? categories;
  List<String>? gameplayCovers;
  String console = "";

  RomInfo({
    required this.slug,
    this.detailsUrl,
    required this.name,
    this.portrait,
    this.logo,
    this.rating,
    this.titleImage,
    this.releaseDate,
    this.categories,
    this.gameplayCovers,
    required this.console,
  });

  RomInfo.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    portrait = json['portrait'];
    logo = json['logo'];
    titleImage = json['titleImage'];
    gameplayCovers = json['gameplayCovers'] != null
        ? List<String>.from(json['gameplayCovers'])
        : null;
    console = json['console'];
    slug = json['slug'];
    detailsUrl = json['detailsUrl'];
    releaseDate = json['releaseDate'];
    rating = json['rating'];
    categories = json['categories'] != null
        ? List<String>.from(json['categories'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['portrait'] = this.portrait;
    data['logo'] = this.logo;
    data['titleImage'] = this.titleImage;
    data['gameplayCovers'] = this.gameplayCovers;
    data['console'] = this.console;
    data['slug'] = this.slug;
    data['detailsUrl'] = this.detailsUrl;
    data['releaseDate'] = this.releaseDate;
    data['rating'] = this.rating;
    data['categories'] = this.categories;
    return data;
  }
}
