class DebriderCredentials {
  String? apiKey;

  DebriderCredentials({this.apiKey});

  DebriderCredentials.fromJson(Map<String, dynamic> json) {
    apiKey = json['apiKey'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['apiKey'] = this.apiKey;
    return data;
  }
}
