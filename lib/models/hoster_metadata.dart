enum HosterStatus { Invalid, Valid, NeedsManual, Unsupported, Unknown }

class HosterMetadata {
  final String? fileName;
  final HosterStatus status;
  const HosterMetadata({this.fileName, this.status = HosterStatus.Unknown});
}
