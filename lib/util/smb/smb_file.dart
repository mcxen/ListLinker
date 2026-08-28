/// Platform-neutral SMB file metadata used by the UI layer.
///
/// The native SMB client is intentionally kept behind the IO-only service
/// implementation so Web builds do not compile its VM-only protocol code.
class SmbFile {
  const SmbFile({
    required this.path,
    required this.uncPath,
    required this.share,
    required this.name,
    required this.size,
    required this.lastModified,
    required this.directory,
    this.createTime = 0,
    this.lastAccess = 0,
    this.attributes = 0,
    this.isExists = true,
    this.nativeHandle,
  });

  final String path;
  final String uncPath;
  final String share;
  final String name;
  final int createTime;
  final int lastModified;
  final int lastAccess;
  final int attributes;
  final int size;
  final bool isExists;
  final bool directory;
  final Object? nativeHandle;

  bool isDirectory() => directory;
  bool isFile() => !directory;

  @override
  String toString() =>
      'SmbFile(name: $name, path: $path, uncPath: $uncPath, share: $share, '
      'size: $size, isDirectory: $directory, isExists: $isExists)';
}
