class DebriderIsProcessingException implements Exception {
  final String message;

  DebriderIsProcessingException(this.message);

  @override
  String toString() =>
      'The debrid service is still processing the file, wait a few minutes and try it again: $message';
}
