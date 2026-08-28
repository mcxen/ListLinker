import 'package:flustars/flustars.dart';
import 'package:get/get.dart';
import 'package:list_linker/util/constant.dart';
import 'package:list_linker/util/smb/smb_connection_config.dart';
import 'package:list_linker/util/smb/smb_file.dart';
import 'package:uuid/uuid.dart';

/// Web-safe SMB service surface.
///
/// SMB transport is native-only. Keeping this implementation separate avoids
/// compiling the VM protocol library into the Web bundle while preserving the
/// saved-connection UI and a clear unsupported-operation error.
class SmbService extends GetxService {
  final connections = <SmbConnectionConfig>[].obs;
  SmbConnectionConfig? activeConfig;

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
    if (activeConfig?.id == id) activeConfig = null;
    await saveConnections();
  }

  Future<void> connect(SmbConnectionConfig config) async {
    throw _unsupported;
  }

  Future<void> disconnect() async {
    activeConfig = null;
  }

  Future<List<SmbFile>> listShares() async => throw _unsupported;

  Future<List<SmbFile>> listPath(String path) async => throw _unsupported;

  Future<SmbFile> file(String path) async => throw _unsupported;

  Future<SmbFile> createFolder(String path) async => throw _unsupported;

  Future<SmbFile> rename(SmbFile file, String destinationPath) async =>
      throw _unsupported;

  Future<SmbFile> delete(SmbFile file) async => throw _unsupported;

  Future<void> uploadFile(
    Object source,
    String destinationDirectory, {
    void Function(int sent, int total)? onProgress,
  }) async {
    throw _unsupported;
  }

  Future<String> makePlayUrl(SmbFile file) async => throw _unsupported;

  Future<String> downloadFile(
    SmbFile file, {
    void Function(int received, int total)? onProgress,
  }) async =>
      throw _unsupported;

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

  static final UnsupportedError _unsupported = UnsupportedError(
    'SMB connections are not supported on Web',
  );
}
