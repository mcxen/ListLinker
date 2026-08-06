import 'dart:io';

import 'package:list_linker/util/constant.dart';
import 'package:list_linker/util/download/download_manager.dart';
import 'package:list_linker/util/proxy.dart';
import 'package:list_linker/util/smb/smb_connection_config.dart';
import 'package:list_linker/util/smb/smb_proxy_source.dart';
import 'package:flustars/flustars.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:smb_connect/smb_connect.dart';
import 'package:sp_util/sp_util.dart';
import 'package:uuid/uuid.dart';

/// Manages saved SMB connections, active session, and proxy streaming.
class SmbService extends GetxService {
  static const _tag = 'SmbService';

  final connections = <SmbConnectionConfig>[].obs;

  SmbConnect? _connect;
  SmbConnectionConfig? activeConfig;

  ProxyServer get _proxy => Get.find<ProxyServer>();

  Future<SmbService> init() async {
    _loadConnections();
    return this;
  }

  void _loadConnections() {
    final raw = SpUtil.getString(AlistConstant.smbConnections);
    connections.assignAll(SmbConnectionConfig.listFromJsonString(raw));
  }

  Future<void> saveConnections() async {
    await SpUtil.putString(
      AlistConstant.smbConnections,
      SmbConnectionConfig.listToJsonString(connections),
    );
  }

  Future<void> upsertConnection(SmbConnectionConfig config) async {
    final idx = connections.indexWhere((e) => e.id == config.id);
    if (idx >= 0) {
      connections[idx] = config;
    } else {
      connections.add(config);
    }
    await saveConnections();
  }

  Future<void> deleteConnection(String id) async {
    connections.removeWhere((e) => e.id == id);
    if (activeConfig?.id == id) {
      await disconnect();
    }
    await saveConnections();
  }

  Future<void> connect(SmbConnectionConfig config) async {
    await disconnect();
    LogUtil.d('SMB connect ${config.host}:${config.port}', tag: _tag);
    _connect = await SmbConnect.connectAuth(
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

  SmbConnect get requireConnect {
    final c = _connect;
    if (c == null) {
      throw StateError('SMB not connected');
    }
    return c;
  }

  Future<List<SmbFile>> listShares() async {
    return requireConnect.listShares();
  }

  Future<List<SmbFile>> listPath(String path) async {
    final connect = requireConnect;
    final folder = await connect.file(path);
    return connect.listFiles(folder);
  }

  Future<SmbFile> file(String path) async {
    return requireConnect.file(path);
  }

  /// Registers the SMB file on the local HTTP proxy (Range-capable) and returns
  /// an http://127.0.0.1 URL suitable for the built-in / external players.
  Future<String> makePlayUrl(SmbFile file) async {
    await _proxy.start();
    final connect = requireConnect;
    final key = const Uuid().v4();
    _proxy.registerSmbSource(
      key,
      SmbProxySource(connect: connect, file: file),
    );
    return _proxy.makeSmbUri(key).toString();
  }

  /// Download an SMB file into the app downloads directory.
  /// Returns the local absolute path.
  Future<String> downloadFile(
    SmbFile file, {
    void Function(int received, int total)? onProgress,
  }) async {
    final connect = requireConnect;
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

    final total = file.size > 0 ? file.size : await _probeLength(file);
    final sink = File(targetPath).openWrite();
    var received = 0;
    try {
      final stream = await connect.openRead(file);
      await for (final chunk in stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total > 0 ? total : received);
      }
      await sink.flush();
      await sink.close();
      LogUtil.d('SMB downloaded $targetPath ($received bytes)', tag: _tag);
      return targetPath;
    } catch (e) {
      await sink.close();
      try {
        await File(targetPath).delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<Directory> _smbDownloadDir() async {
    // Prefer app external storage; fall back to temp Downloads.
    try {
      return await DownloadManager.findDownloadDir('SMB');
    } catch (_) {
      final base = await DownloadManager.acquireDownloadDirectory();
      final dir = Directory(p.join(base.path, 'SMB'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
  }

  Future<int> _probeLength(SmbFile file) async {
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
