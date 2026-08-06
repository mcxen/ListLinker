import 'dart:io';

import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/screen/video_player_screen.dart';
import 'package:list_linker/util/file_type.dart';
import 'package:list_linker/util/file_utils.dart';
import 'package:list_linker/util/named_router.dart';
import 'package:list_linker/util/video_player_util.dart';
import 'package:list_linker/util/widget_utils.dart';
import 'package:list_linker/widget/alist_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_document_picker/flutter_document_picker.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// Pick and play local video files from the device.
class LocalVideoScreen extends StatefulWidget {
  const LocalVideoScreen({super.key});

  @override
  State<LocalVideoScreen> createState() => _LocalVideoScreenState();
}

class _LocalVideoScreenState extends State<LocalVideoScreen> {
  final List<_LocalVideoEntry> _recent = [];

  @override
  Widget build(BuildContext context) {
    return AlistScaffold(
      appbarTitle: Text(Intl.screenName_localVideos.tr),
      appbarActions: [
        IconButton(
          onPressed: () => Get.toNamed(NamedRouter.localStorageBrowser),
          icon: const Icon(Icons.sd_storage_outlined),
          tooltip: Intl.localVideos_browseStorage.tr,
        ),
        IconButton(
          onPressed: _pickFromGallery,
          icon: const Icon(Icons.video_library_outlined),
          tooltip: Intl.localVideos_pickGallery.tr,
        ),
        IconButton(
          onPressed: _pickDocuments,
          icon: const Icon(Icons.folder_open_rounded),
          tooltip: Intl.localVideos_pickFiles.tr,
        ),
      ],
      body: _recent.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.video_file_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      Intl.localVideos_emptyHint.tr,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.video_library_outlined),
                      label: Text(Intl.localVideos_pickGallery.tr),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickDocuments,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: Text(Intl.localVideos_pickFiles.tr),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Get.toNamed(NamedRouter.localStorageBrowser),
                      icon: const Icon(Icons.sd_storage_outlined),
                      label: Text(Intl.localVideos_browseStorage.tr),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: WidgetUtils.listViewPadding(context),
              itemCount: _recent.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _recent[index];
                return ListTile(
                  leading: const Icon(Icons.movie_outlined),
                  title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    item.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () => _playAt(index),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle_outline),
                    onPressed: () => _playAt(index),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      await _addAndPlay([file.path]);
    } catch (e) {
      SmartDialog.showToast('${Intl.localVideos_pickFailed.tr}: $e');
    }
  }

  Future<void> _pickDocuments() async {
    try {
      SmartDialog.showLoading();
      final paths = await FlutterDocumentPicker.openDocuments(
        params: FlutterDocumentPickerParams(
          allowedFileExtensions: _videoExtensions,
        ),
      );
      SmartDialog.dismiss();
      if (paths == null || paths.isEmpty) return;
      final valid = paths.whereType<String>().where((e) => e.isNotEmpty).toList();
      if (valid.isEmpty) return;
      await _addAndPlay(valid);
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('${Intl.localVideos_pickFailed.tr}: $e');
    }
  }

  Future<void> _addAndPlay(List<String> paths) async {
    final entries = <_LocalVideoEntry>[];
    for (final path in paths) {
      final name = p.basename(path);
      final type = FileUtils.getFileType(false, name);
      // Accept explicit video types, or unknown extension files when user picked them.
      if (type != FileType.video && !_looksLikeVideo(name)) {
        continue;
      }
      if (!path.startsWith('content://') && !File(path).existsSync()) {
        continue;
      }
      entries.add(_LocalVideoEntry(name: name, path: path));
    }
    if (entries.isEmpty) {
      SmartDialog.showToast(Intl.localVideos_noVideoSelected.tr);
      return;
    }
    setState(() {
      for (final e in entries.reversed) {
        _recent.removeWhere((x) => x.path == e.path);
        _recent.insert(0, e);
      }
      if (_recent.length > 50) {
        _recent.removeRange(50, _recent.length);
      }
    });
    _playAt(0);
  }

  void _playAt(int index) {
    if (index < 0 || index >= _recent.length) return;
    final videos = _recent
        .map(
          (e) => VideoItem(
            name: e.name,
            localPath: e.path,
            remotePath: e.path,
            sign: '',
            provider: 'Local',
            thumb: null,
            size: _safeFileSize(e.path),
            modifiedMilliseconds: 0,
          ),
        )
        .toList();
    VideoPlayerUtil.go(videos, index, null);
  }

  int? _safeFileSize(String path) {
    try {
      if (path.startsWith('content://')) return null;
      return File(path).lengthSync();
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeVideo(String name) {
    final lower = name.toLowerCase();
    return _videoExtensions.any((ext) => lower.endsWith('.$ext'));
  }

  static const _videoExtensions = [
    'mp4',
    'mkv',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'm4v',
    'ts',
    'm2ts',
    '3gp',
    'rmvb',
    'rm',
  ];
}

class _LocalVideoEntry {
  _LocalVideoEntry({required this.name, required this.path});
  final String name;
  final String path;
}
