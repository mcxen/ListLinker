import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class LocalFileEntry {
  const LocalFileEntry({
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.modified,
    required this.changed,
  });

  final String path;
  final String name;
  final FileSystemEntityType type;
  final int size;
  final DateTime modified;
  final DateTime changed;

  bool get isDirectory => type == FileSystemEntityType.directory;
  bool get isFile => type == FileSystemEntityType.file;
  bool get isLink => type == FileSystemEntityType.link;
  bool get isHidden => name.startsWith('.');
  String get extension => isDirectory ? '' : p.extension(name).toLowerCase();
}

class LocalTrashItem {
  const LocalTrashItem({
    required this.entry,
    required this.originalPath,
    required this.deletedAt,
  });

  final LocalFileEntry entry;
  final String originalPath;
  final DateTime deletedAt;
}

class LocalOperationCancelled implements Exception {
  const LocalOperationCancelled();

  @override
  String toString() => 'File operation cancelled';
}

class LocalOperationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const LocalOperationCancelled();
  }
}

class LocalFileService {
  static const trashDirectoryName = '.listlinker-trash';
  static const _trashIndexName = 'index.json';

  Future<List<LocalFileEntry>> listDirectory(
    String path, {
    bool showHidden = false,
  }) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      throw FileSystemException('Directory not found', path);
    }

    final entries = <LocalFileEntry>[];
    await for (final entity in directory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name == trashDirectoryName) continue;
      if (!showHidden && name.startsWith('.')) continue;
      entries.add(await inspect(entity.path));
    }
    return entries;
  }

  Future<List<LocalFileEntry>> searchDirectory(
    String path,
    String query, {
    bool showHidden = false,
    int maxResults = 1000,
    LocalOperationToken? cancellationToken,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const [];

    final root = Directory(path);
    if (!await root.exists()) {
      throw FileSystemException('Directory not found', path);
    }

    final results = <LocalFileEntry>[];

    Future<void> visit(Directory directory) async {
      cancellationToken?.throwIfCancelled();
      if (results.length >= maxResults) return;

      try {
        await for (final entity in directory.list(followLinks: false)) {
          cancellationToken?.throwIfCancelled();
          if (results.length >= maxResults) return;

          final name = p.basename(entity.path);
          if (name == trashDirectoryName) continue;
          if (!showHidden && name.startsWith('.')) continue;

          final type = await FileSystemEntity.type(
            entity.path,
            followLinks: false,
          );
          if (name.toLowerCase().contains(normalizedQuery)) {
            try {
              results.add(await inspect(entity.path));
            } on FileSystemException {
              // A file may disappear while a live search is scanning.
            }
          }
          if (type == FileSystemEntityType.directory) {
            await visit(Directory(entity.path));
          }
        }
      } on FileSystemException {
        // Keep partial results when a nested folder cannot be read.
      }
    }

    await visit(root);
    cancellationToken?.throwIfCancelled();
    return results;
  }

  Future<String> readTextPreview(
    String path, {
    int maxBytes = 512 * 1024,
  }) async {
    final file = File(path);
    final handle = await file.open();
    try {
      final length = await handle.length();
      final bytes = await handle.read(length.clamp(0, maxBytes).toInt());
      final text = utf8.decode(bytes, allowMalformed: true);
      return length > maxBytes ? '$text\n\n…' : text;
    } finally {
      await handle.close();
    }
  }

  Future<LocalFileEntry> inspect(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      throw FileSystemException('File not found', path);
    }
    final stat = await FileStat.stat(path);
    return LocalFileEntry(
      path: path,
      name: p.basename(path),
      type: type,
      size: type == FileSystemEntityType.file ? stat.size : 0,
      modified: stat.modified,
      changed: stat.changed,
    );
  }

  Future<String> createFolder(String parent, String name) async {
    final safeName = validateName(name);
    final target = p.join(parent, safeName);
    if (await FileSystemEntity.type(target, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('A file with this name already exists', target);
    }
    return (await Directory(target).create()).path;
  }

  Future<String> renameEntry(String source, String newName) async {
    final safeName = validateName(newName);
    final target = p.join(p.dirname(source), safeName);
    if (p.normalize(source) == p.normalize(target)) return source;
    if (await FileSystemEntity.type(target, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw FileSystemException('A file with this name already exists', target);
    }
    return _rename(source, target);
  }

  Future<List<String>> copyEntries(
    Iterable<String> sources,
    String destinationDirectory, {
    void Function(int completed, int total, String path)? onProgress,
    LocalOperationToken? cancellationToken,
  }) async {
    final sourceList = sources.toList(growable: false);
    final results = <String>[];
    for (var index = 0; index < sourceList.length; index++) {
      cancellationToken?.throwIfCancelled();
      final source = sourceList[index];
      _validateDestination(source, destinationDirectory);
      final target = await uniquePath(
        p.join(destinationDirectory, p.basename(source)),
      );
      await _copy(source, target, cancellationToken: cancellationToken);
      results.add(target);
      onProgress?.call(index + 1, sourceList.length, source);
    }
    cancellationToken?.throwIfCancelled();
    return results;
  }

  Future<List<String>> moveEntries(
    Iterable<String> sources,
    String destinationDirectory, {
    void Function(int completed, int total, String path)? onProgress,
    LocalOperationToken? cancellationToken,
  }) async {
    final sourceList = sources.toList(growable: false);
    final results = <String>[];
    for (var index = 0; index < sourceList.length; index++) {
      cancellationToken?.throwIfCancelled();
      final source = sourceList[index];
      _validateDestination(source, destinationDirectory);
      final target = await uniquePath(
        p.join(destinationDirectory, p.basename(source)),
      );
      try {
        results.add(await _rename(source, target));
      } on FileSystemException {
        await _copy(source, target, cancellationToken: cancellationToken);
        cancellationToken?.throwIfCancelled();
        await _delete(source);
        results.add(target);
      }
      onProgress?.call(index + 1, sourceList.length, source);
    }
    cancellationToken?.throwIfCancelled();
    return results;
  }

  Future<List<String>> duplicateEntries(
    Iterable<String> sources, {
    void Function(int completed, int total, String path)? onProgress,
    LocalOperationToken? cancellationToken,
  }) async {
    final sourceList = sources.toList(growable: false);
    final results = <String>[];
    for (var index = 0; index < sourceList.length; index++) {
      cancellationToken?.throwIfCancelled();
      final source = sourceList[index];
      final target = await uniquePath(
        p.join(p.dirname(source), p.basename(source)),
        copySuffix: true,
      );
      await _copy(source, target, cancellationToken: cancellationToken);
      results.add(target);
      onProgress?.call(index + 1, sourceList.length, source);
    }
    cancellationToken?.throwIfCancelled();
    return results;
  }

  Future<List<String>> renameEntries(
    Map<String, String> names, {
    void Function(int completed, int total, String path)? onProgress,
    LocalOperationToken? cancellationToken,
  }) async {
    if (names.isEmpty) return const [];

    final sources = names.keys.toList(growable: false);
    final targets = <String>[];
    final canonicalTargets = <String>{};
    final canonicalSources = sources.map(_canonicalPath).toSet();

    for (final source in sources) {
      final name = validateName(names[source] ?? '');
      final target = p.join(p.dirname(source), name);
      final canonicalTarget = _canonicalPath(target);
      if (!canonicalTargets.add(canonicalTarget)) {
        throw FileSystemException('More than one item has the same name', target);
      }
      final existing = await FileSystemEntity.type(
        target,
        followLinks: false,
      );
      if (existing != FileSystemEntityType.notFound &&
          !canonicalSources.contains(canonicalTarget)) {
        throw FileSystemException('A file with this name already exists', target);
      }
      targets.add(target);
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final temporary = <String>[];
    for (var index = 0; index < sources.length; index++) {
      temporary.add(
        await uniquePath(
          p.join(
            p.dirname(sources[index]),
            '.listlinker-rename-$stamp-$index',
          ),
        ),
      );
    }

    final staged = <int>[];
    final completed = <int>[];
    try {
      for (var index = 0; index < sources.length; index++) {
        cancellationToken?.throwIfCancelled();
        await _rename(sources[index], temporary[index]);
        staged.add(index);
      }
      for (var index = 0; index < temporary.length; index++) {
        cancellationToken?.throwIfCancelled();
        await _rename(temporary[index], targets[index]);
        completed.add(index);
        onProgress?.call(index + 1, sources.length, targets[index]);
      }
      return targets;
    } catch (_) {
      for (final index in completed.reversed) {
        try {
          await _rename(targets[index], sources[index]);
        } on FileSystemException {
          // Best-effort rollback; keep the original error.
        }
      }
      for (final index in staged.reversed) {
        if (completed.contains(index)) continue;
        try {
          await _rename(temporary[index], sources[index]);
        } on FileSystemException {
          // Best-effort rollback; keep the original error.
        }
      }
      rethrow;
    }
  }

  Future<void> moveToTrash(
    Iterable<String> sources,
    String root, {
    void Function(int completed, int total, String path)? onProgress,
    LocalOperationToken? cancellationToken,
  }) async {
    final sourceList = sources.toList(growable: false);
    final trash = Directory(p.join(root, trashDirectoryName));
    await trash.create(recursive: true);
    final records = await _readTrashIndex(root);

    for (var index = 0; index < sourceList.length; index++) {
      cancellationToken?.throwIfCancelled();
      final source = sourceList[index];
      if (!p.isWithin(root, source)) {
        throw FileSystemException('Item is outside the selected root', source);
      }
      if (p.isWithin(trash.path, source) || p.equals(trash.path, source)) {
        throw FileSystemException('Item is already in trash', source);
      }
      final storedName =
          '${DateTime.now().microsecondsSinceEpoch}_${p.basename(source)}';
      final target = p.join(trash.path, storedName);
      await _rename(source, target);
      records[storedName] = <String, Object>{
        'originalPath': source,
        'deletedAt': DateTime.now().toIso8601String(),
      };
      onProgress?.call(index + 1, sourceList.length, source);
    }
    await _writeTrashIndex(root, records);
  }

  Future<List<LocalTrashItem>> listTrash(String root) async {
    final trash = Directory(p.join(root, trashDirectoryName));
    if (!await trash.exists()) return const [];
    final records = await _readTrashIndex(root);
    final items = <LocalTrashItem>[];

    await for (final entity in trash.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name == _trashIndexName) continue;
      final record = records[name];
      if (record == null) continue;
      final originalPath = record['originalPath'];
      final deletedAt = record['deletedAt'];
      if (originalPath is! String || deletedAt is! String) continue;
      items.add(
        LocalTrashItem(
          entry: await inspect(entity.path),
          originalPath: originalPath,
          deletedAt: DateTime.tryParse(deletedAt) ?? DateTime.now(),
        ),
      );
    }
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return items;
  }

  Future<String> restoreTrashItem(LocalTrashItem item, String root) async {
    final records = await _readTrashIndex(root);
    final storedName = p.basename(item.entry.path);
    final parent = Directory(p.dirname(item.originalPath));
    await parent.create(recursive: true);
    final target = await uniquePath(item.originalPath);
    await _rename(item.entry.path, target);
    records.remove(storedName);
    await _writeTrashIndex(root, records);
    return target;
  }

  Future<void> deleteTrashItems(
    Iterable<LocalTrashItem> items,
    String root, {
    LocalOperationToken? cancellationToken,
    void Function(int completed, int total, String path)? onProgress,
  }) async {
    final records = await _readTrashIndex(root);
    final itemList = items.toList(growable: false);
    for (var index = 0; index < itemList.length; index++) {
      cancellationToken?.throwIfCancelled();
      final item = itemList[index];
      await _delete(item.entry.path);
      records.remove(p.basename(item.entry.path));
      onProgress?.call(index + 1, itemList.length, item.entry.path);
    }
    await _writeTrashIndex(root, records);
  }

  Future<void> emptyTrash(
    String root, {
    LocalOperationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final trash = Directory(p.join(root, trashDirectoryName));
    if (await trash.exists()) await trash.delete(recursive: true);
  }

  String validateName(String value) {
    final name = value.trim();
    if (name.isEmpty || name == '.' || name == '..') {
      throw const FormatException('Name cannot be empty');
    }
    if (name.contains('/') || name.contains('\\')) {
      throw const FormatException('Name cannot contain path separators');
    }
    if (Platform.isWindows && RegExp(r'[<>:"|?*]').hasMatch(name)) {
      throw const FormatException('Name contains unsupported characters');
    }
    return name;
  }

  Future<String> uniquePath(
    String desired, {
    bool copySuffix = false,
  }) async {
    if (await FileSystemEntity.type(desired, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return desired;
    }

    final directory = p.dirname(desired);
    final extension = p.extension(desired);
    final base = p.basenameWithoutExtension(desired);
    for (var index = 1; index < 10000; index++) {
      final suffix =
          copySuffix ? (index == 1 ? ' copy' : ' copy $index') : ' ($index)';
      final candidate = p.join(directory, '$base$suffix$extension');
      if (await FileSystemEntity.type(candidate, followLinks: false) ==
          FileSystemEntityType.notFound) {
        return candidate;
      }
    }
    throw FileSystemException('Could not create a unique name', desired);
  }

  void _validateDestination(String source, String destinationDirectory) {
    final normalizedSource = p.normalize(p.absolute(source));
    final normalizedDestination = p.normalize(p.absolute(destinationDirectory));
    if (p.equals(p.dirname(normalizedSource), normalizedDestination)) {
      return;
    }
    if (p.isWithin(normalizedSource, normalizedDestination)) {
      throw FileSystemException(
        'Cannot place a folder inside itself',
        destinationDirectory,
      );
    }
  }

  String _canonicalPath(String path) {
    final normalized = p.normalize(p.absolute(path));
    return Platform.isWindows || Platform.isMacOS
        ? normalized.toLowerCase()
        : normalized;
  }

  Future<void> _copy(
    String source,
    String target, {
    LocalOperationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    final type = await FileSystemEntity.type(source, followLinks: false);
    switch (type) {
      case FileSystemEntityType.directory:
        final destination = await Directory(target).create(recursive: true);
        await for (final child in Directory(source).list(followLinks: false)) {
          cancellationToken?.throwIfCancelled();
          await _copy(
            child.path,
            p.join(destination.path, p.basename(child.path)),
            cancellationToken: cancellationToken,
          );
        }
      case FileSystemEntityType.file:
        await File(source).copy(target);
      case FileSystemEntityType.link:
        final linkTarget = await Link(source).target();
        await Link(target).create(linkTarget);
      case FileSystemEntityType.notFound:
        throw FileSystemException('File not found', source);
      default:
        throw FileSystemException('Unsupported file type', source);
    }
  }

  Future<String> _rename(String source, String target) async {
    final type = await FileSystemEntity.type(source, followLinks: false);
    switch (type) {
      case FileSystemEntityType.directory:
        return (await Directory(source).rename(target)).path;
      case FileSystemEntityType.file:
        return (await File(source).rename(target)).path;
      case FileSystemEntityType.link:
        return (await Link(source).rename(target)).path;
      case FileSystemEntityType.notFound:
        throw FileSystemException('File not found', source);
      default:
        throw FileSystemException('Unsupported file type', source);
    }
  }

  Future<void> _delete(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    switch (type) {
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      case FileSystemEntityType.file:
        await File(path).delete();
      case FileSystemEntityType.link:
        await Link(path).delete();
      case FileSystemEntityType.notFound:
        return;
      default:
        throw FileSystemException('Unsupported file type', path);
    }
  }

  Future<Map<String, Map<String, Object>>> _readTrashIndex(String root) async {
    final file = File(p.join(root, trashDirectoryName, _trashIndexName));
    if (!await file.exists()) return <String, Map<String, Object>>{};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return <String, Map<String, Object>>{};
      return decoded.map<String, Map<String, Object>>((key, value) {
        final record = value is Map
            ? value.map<String, Object>(
                (recordKey, recordValue) =>
                    MapEntry(recordKey.toString(), recordValue as Object),
              )
            : <String, Object>{};
        return MapEntry(key.toString(), record);
      });
    } catch (_) {
      return <String, Map<String, Object>>{};
    }
  }

  Future<void> _writeTrashIndex(
    String root,
    Map<String, Map<String, Object>> records,
  ) async {
    final trash = Directory(p.join(root, trashDirectoryName));
    await trash.create(recursive: true);
    final file = File(p.join(trash.path, _trashIndexName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(records),
      flush: true,
    );
  }
}
