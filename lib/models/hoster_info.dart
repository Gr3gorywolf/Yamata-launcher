class HosterInfo {
  final String uri;
  final String domain;
  final String? fileName;
  final bool isDirect;
  final bool canExtractLink;

  HosterInfo(
      {required this.uri,
      required this.domain,
      this.fileName,
      required this.isDirect,
      required this.canExtractLink});
}
