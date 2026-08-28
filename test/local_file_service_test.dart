import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:list_linker/util/local_file_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandbox;
  late LocalFileService service;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('listlinker-files-');
    service = LocalFileService();
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('lists, creates, renames, duplicates and copies entries', () async {
    final source = File(p.join(sandbox.path, 'notes.txt'));
    await source.writeAsString('ListLinker');
    await service.createFolder(sandbox.path, 'Folder');

    final listed = await service.listDirectory(sandbox.path);
    expect(listed.map((entry) => entry.name),
        containsAll(['notes.txt', 'Folder']));

    final renamed = await service.renameEntry(source.path, 'readme.txt');
    expect(await File(renamed).readAsString(), 'ListLinker');

    final duplicates = await service.duplicateEntries([renamed]);
    expect(p.basename(duplicates.single), 'readme copy.txt');

    final target = Directory(p.join(sandbox.path, 'Target'));
    await target.create();
    final copies = await service.copyEntries([renamed], target.path);
    expect(await File(copies.single).readAsString(), 'ListLinker');
  });

  test('moves entries to recoverable trash and restores them', () async {
    final source = File(p.join(sandbox.path, 'recover.txt'));
    await source.writeAsString('recover me');

    await service.moveToTrash([source.path], sandbox.path);
    expect(await source.exists(), isFalse);

    final trash = await service.listTrash(sandbox.path);
    expect(trash, hasLength(1));
    expect(trash.single.originalPath, source.path);

    final restored = await service.restoreTrashItem(trash.single, sandbox.path);
    expect(restored, source.path);
    expect(await File(restored).readAsString(), 'recover me');
    expect(await service.listTrash(sandbox.path), isEmpty);
  });

  test('permanently deletes selected trash entries', () async {
    final source = File(p.join(sandbox.path, 'remove.txt'));
    await source.writeAsString('remove me');
    await service.moveToTrash([source.path], sandbox.path);

    final trash = await service.listTrash(sandbox.path);
    await service.deleteTrashItems(trash, sandbox.path);

    expect(await service.listTrash(sandbox.path), isEmpty);
  });
}
