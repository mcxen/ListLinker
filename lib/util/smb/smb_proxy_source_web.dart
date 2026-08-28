/// Web placeholder for the native SMB proxy source.
class SmbProxySource {
  Future<int> length() async => throw UnsupportedError(
        'SMB streaming is not supported on Web',
      );

  Future<void> writeRange(Object response, int start, int end) async =>
      throw UnsupportedError('SMB streaming is not supported on Web');

  Future<void> writeAll(Object response) async =>
      throw UnsupportedError('SMB streaming is not supported on Web');
}
