import 'dart:io';

import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/screen/video_player_screen.dart';
import 'package:list_linker/util/file_type.dart';
import 'package:list_linker/util/file_utils.dart';
import 'package:list_linker/util/named_router.dart';
import 'package:list_linker/util/video_player_util.dart';
import 'package:list_linker/widget/alist_scaffold.dart';
import 'package:list_linker/widget/app_ui.dart';
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
      body: _recent.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      padding: AppUi.pageInsets(context, top: 20),
      children: [
        AppEmptyState(
          expand: false,
          icon: Icons.movie_filter_outlined,
          title: Intl.screenName_localVideos.tr,
          body: Intl.localVideos_emptyHint.tr,
        ),
        const SizedBox(height: 28),
        AppSectionHeader(Intl.localVideos_section_sources.tr),
        Row(
          children: [
            Expanded(
              child: AppActionCard(
                icon: Icons.video_library_rounded,
                label: Intl.localVideos_pickGallery.tr,
                caption: Intl.localVideos_caption_gallery.tr,
                onTap: _pickFromGallery,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppActionCard(
                icon: Icons.folder_open_rounded,
                label: Intl.localVideos_pickFiles.tr,
                caption: Intl.localVideos_caption_files.tr,
                onTap: _pickDocuments,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppActionCard(
          icon: Icons.sd_storage_rounded,
          label: Intl.localVideos_browseStorage.tr,
          caption: Intl.localVideos_caption_storage.tr,
          onTap: () => Get.toNamed(NamedRouter.localStorageBrowser),
        ),
      ],
    );
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: AppSectionHeader(Intl.localVideos_section_recent.tr),
              ),
              TextButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(Intl.localVideos_add.tr),
              ),
              IconButton(
                tooltip: Intl.localVideos_browseStorage.tr,
                onPressed: () => Get.toNamed(NamedRouter.localStorageBrowser),
                icon: const Icon(Icons.sd_storage_outlined),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(
              bottom: 16 +
                  MediaQuery.viewPaddingOf(context).bottom,
            ),
            itemCount: _recent.length,
            separatorBuilder: (_, __) => const AppInsetDivider(),
            itemBuilder: (context, index) {
              final item = _recent[index];
              return AppListTile(
                leadingIcon: Icons.movie_outlined,
                title: item.name,
                subtitle: item.path,
                onTap: () => _playAt(index),
                trailing: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              );
            },
          ),
        ),
      ],
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
      final valid =
          paths.whereType<String>().where((e) => e.isNotEmpty).toList();
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
