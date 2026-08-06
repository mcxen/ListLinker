import 'dart:io';

import 'package:list_linker/generated/images.dart';
import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/screen/video_player_screen.dart';
import 'package:list_linker/util/file_type.dart';
import 'package:list_linker/util/file_utils.dart';
import 'package:list_linker/util/named_router.dart';
import 'package:list_linker/util/video_player_util.dart';
import 'package:list_linker/util/widget_utils.dart';
import 'package:list_linker/widget/alist_scaffold.dart';
import 'package:list_linker/widget/file_list_item_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Browse local device folders and play video files.
class LocalStorageBrowserScreen extends StatefulWidget {
  const LocalStorageBrowserScreen({super.key});

  @override
  State<LocalStorageBrowserScreen> createState() =>
      _LocalStorageBrowserScreenState();
}

class _LocalStorageBrowserScreenState extends State<LocalStorageBrowserScreen> {
  String? _root;
  late String _path;
  bool _loading = true;
  String? _error;
  List<FileSystemEntity> _entries = [];

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map? ?? {};
    _path = (args['path'] as String?) ?? '';
    _root = args['root'] as String?;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_path.isEmpty) {
      await _requestPermission();
      _path = await _resolveStartPath();
      _root ??= _path;
    }
    await _load();
  }

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid) return;
    // Android 13+ media; older storage.
    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();
    final storage = await Permission.storage.request();
    if (photos.isDenied && videos.isDenied && storage.isDenied) {
      // continue with app-specific dirs only
    }
  }

  Future<String> _resolveStartPath() async {
    if (Platform.isAndroid) {
      // Prefer public-ish external storage root when readable.
      const emulated = '/storage/emulated/0';
      if (await Directory(emulated).exists()) {
        try {
          // Probe readability (empty dir is still OK).
          await Directory(emulated).list(followLinks: false).take(1).toList();
          return emulated;
        } catch (_) {}
      }
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext.path;
    }
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dir = Directory(_path);
      if (!await dir.exists()) {
        throw Exception('Path not found: $_path');
      }
      final list = await dir.list(followLinks: false).toList();
      list.sort((a, b) {
        final aDir = a is Directory;
        final bDir = b is Directory;
        if (aDir != bDir) return aDir ? -1 : 1;
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = p.basename(_path).isEmpty ? _path : p.basename(_path);
    return AlistScaffold(
      appbarTitle: Text(title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: Text(Intl.smb_retry.tr),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            await openAppSettings();
                          },
                          child: Text(Intl.localStorage_openSettings.tr),
                        ),
                      ],
                    ),
                  ),
                )
              : _entries.isEmpty
                  ? Center(child: Text(Intl.smb_folderEmpty.tr))
                  : ListView.separated(
                      padding: WidgetUtils.listViewPadding(context),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entity = _entries[index];
                        final name = p.basename(entity.path);
                        final isDir = entity is Directory;
                        final icon = isDir
                            ? Images.fileTypeFolder
                            : FileUtils.getFileIcon(false, name);
                        String? sizeDesc;
                        if (!isDir) {
                          try {
                            sizeDesc = FileUtils.formatBytes(
                                File(entity.path).lengthSync());
                          } catch (_) {}
                        }
                        return FileListItemView(
                          icon: icon,
                          fileName: name,
                          time: null,
                          sizeDesc: sizeDesc,
                          onTap: () => _onTap(entity, isDir),
                        );
                      },
                    ),
    );
  }

  void _onTap(FileSystemEntity entity, bool isDir) {
    if (isDir) {
      Get.toNamed(
        NamedRouter.localStorageBrowser,
        arguments: {
          'path': entity.path,
          'root': _root,
        },
        preventDuplicates: false,
      );
      return;
    }
    final name = p.basename(entity.path);
    if (FileUtils.getFileType(false, name) != FileType.video) {
      SmartDialog.showToast(Intl.smb_notVideo.tr);
      return;
    }
    final videos = _entries
        .whereType<File>()
        .where((f) =>
            FileUtils.getFileType(false, p.basename(f.path)) == FileType.video)
        .map(
          (f) => VideoItem(
            name: p.basename(f.path),
            localPath: f.path,
            remotePath: f.path,
            sign: '',
            provider: 'Local',
            thumb: null,
            size: () {
              try {
                return f.lengthSync();
              } catch (_) {
                return null;
              }
            }(),
            modifiedMilliseconds: 0,
          ),
        )
        .toList();
    final index = videos.indexWhere((v) => v.localPath == entity.path);
    if (index < 0) return;
    VideoPlayerUtil.go(videos, index, null);
  }
}
