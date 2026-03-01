class DownloadRequireManualException implements Exception {
  final String message;

  DownloadRequireManualException(this.message);

  @override
  String toString() => 'Require manual: $message';
}
