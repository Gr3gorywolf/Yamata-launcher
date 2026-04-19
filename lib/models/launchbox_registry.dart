class LaunchboxRegistry {
  String name = "";
  String slug = "";
  String console = "";

  LaunchboxRegistry(
      {required this.name, required this.slug, required this.console});

  LaunchboxRegistry.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    slug = json['slug'];
    console = json['console'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['name'] = this.name;
    data['slug'] = this.slug;
    data['console'] = this.console;
    return data;
  }
}
