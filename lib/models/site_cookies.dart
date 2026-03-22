class SiteCookies {
  String? cookie;
  String? headers;

  SiteCookies({this.cookie, this.headers});

  SiteCookies.fromJson(Map<String, dynamic> json) {
    cookie = json['cookie'];
    headers = json['headers'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['cookie'] = this.cookie;
    data['headers'] = this.headers;
    return data;
  }
}
