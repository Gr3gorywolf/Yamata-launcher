class Emulator {
  String? name;
  String? image;
  String? downloadLink;
  String? packageName;
  bool? isCompatible;

  Emulator(
      {this.name,
      this.image,
      this.downloadLink,
      this.packageName,
      this.isCompatible});

  Emulator.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    image = json['image'];
    downloadLink = json['download_link'];
    packageName = json['package_name'];
    isCompatible = json['is_compatible'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['image'] = this.image;
    data['download_link'] = this.downloadLink;
    data['package_name'] = this.packageName;
    data['is_compatible'] = this.isCompatible;
    return data;
  }
}
