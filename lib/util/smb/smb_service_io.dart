import 'dart:io';

import 'package:flustars/flustars.dart';
import 'package:get/get.dart';
import 'package:list_linker/util/constant.dart';
import 'package:list_linker/util/download/download_manager.dart';
import 'package:list_linker/util/proxy.dart';
import 'package:list_linker/util/smb/smb_connection_config.dart';
import 'package:list_linker/util/smb/smb_file.dart';
import 'package:list_linker/util/smb/smb_proxy_source.dart';
import 'package:path/path.dart' as p;
import 'package:smb_connect/smb_connect.dart' as native_smb;
import 'package:uuid/uuid.dart';

/// Manages saved SMB connections, active session, and proxy streaming on IO
/// platforms. The native protocol package is kept out of Web builds.
class SmbService extends GetxService {
  static const _tag = 'SmbService';

  final connections = <SmbConnectionConfig>[].obs;

  native_smb.SmbConnect? _connect;
  SmbConnectionConfig? activeConfig;

  ProxyServer get _proxy => Get.find<ProxyServer>();

  Future<SmbService> init() async {
    final raw = SpUtil.getString(AlistConstant.smbConnections);
    connections.assignAll(SmbConnectionConfig.listFromJsonString(raw));
    return this;
  }

  Future<void> saveConnections() async {
    await SpUtil.putString(
      AlistConstant.smbConnections,
      SmbConnectionConfig.listToJsonString(connections),
    );
  }

  Future<void> upsertConnection(SmbConnectionConfig config) async {
    final index = connections.indexWhere((item) => item.id == config.id);
    if (index >= 0) {
      connections[index] = config;
    } else {
      connections.add(config);
    }
    await saveConnections();
  }

  Future<void> deleteConnection(String id) async {
    connections.removeWhere((item) => item.id == id);
    if (activeConfig?.id == id) await disconnect();
    await saveConnections();
  }

  Future<void> connect(SmbConnectionConfig config) async {
    await disconnect();
    LogUtil.d('SMB connect ${config.host}:${config.port}', tag: _tag);
    _connect = await native_smb.SmbConnect.connectAuth(
      host: config.host,
      domain: config.domain,
      username: config.username,
      password: config.password,
    );
    activeConfig = config;
  }

  Future<void> disconnect() async {
    try {
      await _connect?.close();
    } catch (_) {}
    _connect = null;
    activeConfig = null;
    _proxy.clearSmbSources();
  }

  native_smb.SmbConnect get requireConnect {
    final connect = _connect;
    if (connect == null) throw StateError('SMB not connected');
    return connect;
  }

  SmbFile _map(native_smb.SmbFile file) {
    return SmbFile(
      path: file.path,
      uncPath: file.uncPath,
      share: file.share,
      name: file.name,
      createTime: file.createTime,
      lastModified: file.lastModified,
      lastAccess: file.lastAccess,
      attributes: file.attributes,
      size: file.size,
      isExists: file.isExists,
      directory: file.isDirectory(),
      nativeHandle: file,
    );
  }

  native_smb.SmbFile _native(SmbFile file) {
    final nativeFile = file.nativeHandle;
    if (nativeFile is native_smb.SmbFile) return nativeFile;
    throw StateError('SMB file is not attached to the active session');
  }

  Future<List<SmbFile>> listShares() async {
    final files = await requireConnect.listShares();
    return files.map(_map).toList(growable: false);
  }

  Future<List<SmbFile>> listPath(String path) async {
    final connect = requireConnect;
    final folder = await connect.file(path);
    final files = await connect.listFiles(folder);
    return files.map(_map).toList(growable: false);
  }

  Future<SmbFile> file(String path) async =>
      _map(await requireConnect.file(path));

  Future<SmbFile> createFolder(String path) async {
    return _map(await requireConnect.createFolder(path));
  }

  Future<SmbFile> rename(SmbFile file, String destinationPath) async {
    return _map(await requireConnect.rename(_native(file), destinationPath));
  }

  Future<SmbFile> delete(SmbFile file) async {
    return _map(await requireConnect.delete(_native(file)));
  }

  Future<SmbFile> uploadFile(
    File source,
    String destinationDirectory, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final connect = requireConnect;
    final remotePath = destinationDirectory.endsWith('/')
        ? '$destinationDirectory${p.basename(source.path)}'
        : '$destinationDirectory/${p.basename(source.path)}';
    final remote = await connect.createFile(remotePath);
    final sink = await connect.openWrite(remote);
    final total = await source.length();
    var sent = 0;
    try {
      await for (final chunk in source.openRead()) {
        sink.add(chunk);
        sent += chunk.length;
        onProgress?.call(sent, total);
      }
      await sink.flush();
      await sink.close();
      return _map(await connect.file(remotePath));
    } catch (_) {
      await sink.close();
      try {
        await connect.delete(remote);
      } catch (_) {}
      rethrow;
    }
  }

  Future<String> makePlayUrl(SmbFile file) async {
    await _proxy.start();
    final key = const Uuid().v4();
    _proxy.registerSmbSource(
      key,
      SmbProxySource(connect: requireConnect, file: _native(file)),
    );
    return _proxy.makeSmbUri(key).toString();
  }

  Future<String> downloadFile(
    SmbFile file, {
    void Function(int received, int total)? onProgress,
  }) async {
    final connect = requireConnect;
    final nativeFile = _native(file);
    final dir = await _smbDownloadDir();
    final safeName = file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    var targetPath = p.join(dir.path, safeName);
    if (await File(targetPath).exists()) {
      final base = p.basenameWithoutExtension(safeName);
      final ext = p.extension(safeName);
      targetPath = p.join(
        dir.path,
        '${base}_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
    }

    final total = file.size > 0 ? file.size : await _probeLength(nativeFile);
    final sink = File(targetPath).openWrite();
    var received = 0;
    try {
      final stream = await connect.openRead(nativeFile);
      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total > 0 ? total : received);
      }
      await sink.flush();
      await sink.close();
      LogUtil.d('SMB downloaded $targetPath ($received bytes)', tag: _tag);
      return targetPath;
    } catch (_) {
      await sink.close();
      try {
        await File(targetPath).delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<Directory> _smbDownloadDir() async {
    try {
      return await DownloadManager.findDownloadDir('SMB');
    } catch (_) {
      final base = await DownloadManager.acquireDownloadDirectory();
      final dir = Directory(p.join(base.path, 'SMB'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
  }

  Future<int> _probeLength(native_smb.SmbFile file) async {
    try {
      final raf = await requireConnect.open(file);
      try {
        return await raf.length();
      } finally {
        await raf.close();
      }
    } catch (_) {
      return 0;
    }
  }

  static SmbConnectionConfig newConfig({
    required String name,
    required String host,
    int port = 445,
    String domain = '',
    required String username,
    required String password,
    String share = '',
  }) {
    return SmbConnectionConfig(
      id: const Uuid().v4(),
      name: name,
      host: host,
      port: port,
      domain: domain,
      username: username,
      password: password,
      share: share,
    );
  }
}
