class HosterInfo {
  final String uri;
  final String domain;
  final bool isDirect;
  final bool canExtractLink;

  HosterInfo(
      {required this.uri,
      required this.domain,
      required this.isDirect,
      required this.canExtractLink});
}
