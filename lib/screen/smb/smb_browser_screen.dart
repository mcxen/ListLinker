import 'package:list_linker/generated/images.dart';
import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/screen/video_player_screen.dart';
import 'package:list_linker/util/file_type.dart';
import 'package:list_linker/util/file_utils.dart';
import 'package:list_linker/util/named_router.dart';
import 'package:list_linker/util/smb/smb_service.dart';
import 'package:list_linker/util/video_player_util.dart';
import 'package:list_linker/util/widget_utils.dart';
import 'package:list_linker/widget/alist_scaffold.dart';
import 'package:list_linker/widget/file_list_item_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:smb_connect/smb_connect.dart';

/// Browse an SMB share / folder, play videos, and download files.
class SmbBrowserScreen extends StatefulWidget {
  const SmbBrowserScreen({super.key});

  @override
  State<SmbBrowserScreen> createState() => _SmbBrowserScreenState();
}

class _SmbBrowserScreenState extends State<SmbBrowserScreen> {
  final SmbService _smb = Get.find();
  late String _path;
  late String _title;
  bool _loading = true;
  String? _error;
  List<SmbFile> _files = [];
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map? ?? {};
    _path = (args['path'] as String?) ?? '';
    _title = (args['title'] as String?) ?? Intl.screenName_smb.tr;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<SmbFile> list;
      if (_path.isEmpty) {
        list = await _smb.listShares();
      } else {
        final normalized = _path.endsWith('/') ? _path : '$_path/';
        list = await _smb.listPath(normalized);
      }
      list.sort((a, b) {
        if (a.isDirectory() != b.isDirectory()) {
          return a.isDirectory() ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      if (!mounted) return;
      setState(() {
        _files = list;
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
    final parts = _path.split('/').where((e) => e.isNotEmpty).toList();
    final displayTitle = _path.isEmpty
        ? _title
        : (parts.isEmpty ? _title : parts.last);

    return AlistScaffold(
      appbarTitle: Text(displayTitle),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _load,
                              child: Text(Intl.smb_retry.tr),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _files.isEmpty
                      ? Center(child: Text(Intl.smb_folderEmpty.tr))
                      : ListView.separated(
                          padding: WidgetUtils.listViewPadding(context),
                          itemCount: _files.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final file = _files[index];
                            final isDir =
                                file.isDirectory() || _path.isEmpty;
                            final icon = isDir
                                ? Images.fileTypeFolder
                                : FileUtils.getFileIcon(false, file.name);
                            final sizeDesc = isDir
                                ? null
                                : FileUtils.formatBytes(file.size);
                            return FileListItemView(
                              icon: icon,
                              fileName: file.name,
                              time: null,
                              sizeDesc: sizeDesc,
                              onTap: () => _onTap(file, isDir),
                              onMoreIconButtonTap: isDir
                                  ? null
                                  : () => _showFileActions(file),
                            );
                          },
                        ),
          if (_downloadProgress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                elevation: 6,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Intl.smb_downloading.tr),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _downloadProgress),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onTap(SmbFile file, bool isDir) async {
    if (isDir || _path.isEmpty) {
      final nextPath = _path.isEmpty
          ? '/${file.name}'
          : (_path.endsWith('/')
              ? '$_path${file.name}'
              : '$_path/${file.name}');
      Get.toNamed(
        NamedRouter.smbBrowser,
        arguments: {
          'title': _title,
          'path': nextPath,
        },
        preventDuplicates: false,
      );
      return;
    }

    final type = FileUtils.getFileType(false, file.name);
    if (type == FileType.video) {
      await _playVideo(file);
      return;
    }
    // Non-video: open action sheet
    await _showFileActions(file);
  }

  Future<void> _showFileActions(SmbFile file) async {
    final isVideo =
        FileUtils.getFileType(false, file.name) == FileType.video;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(file.name),
                subtitle: Text(FileUtils.formatBytes(file.size) ?? ''),
              ),
              const Divider(height: 1),
              if (isVideo)
                ListTile(
                  leading: const Icon(Icons.play_arrow_rounded),
                  title: Text(Intl.smb_action_play.tr),
                  onTap: () {
                    Navigator.pop(ctx);
                    _playVideo(file);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: Text(Intl.smb_action_download.tr),
                onTap: () {
                  Navigator.pop(ctx);
                  _download(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(Intl.smb_cancel.tr),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _playVideo(SmbFile file) async {
    SmartDialog.showLoading();
    try {
      final videosMeta = _files
          .where((e) =>
              !e.isDirectory() &&
              FileUtils.getFileType(false, e.name) == FileType.video)
          .toList();
      final playItems = <VideoItem>[];
      for (final v in videosMeta) {
        final url = await _smb.makePlayUrl(v);
        playItems.add(
          VideoItem(
            name: v.name,
            remotePath: v.path,
            localPath: null,
            playUrl: url,
            sign: '',
            provider: 'SMB',
            thumb: null,
            size: v.size,
            modifiedMilliseconds: v.lastModified,
          ),
        );
      }
      SmartDialog.dismiss();
      final index = playItems.indexWhere((e) => e.remotePath == file.path);
      if (index < 0) {
        SmartDialog.showToast(Intl.smb_notVideo.tr);
        return;
      }
      VideoPlayerUtil.go(playItems, index, null);
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('${Intl.smb_playFailed.tr}: $e');
    }
  }

  Future<void> _download(SmbFile file) async {
    if (file.isDirectory()) return;
    setState(() => _downloadProgress = 0);
    try {
      final path = await _smb.downloadFile(
        file,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress =
                total > 0 ? (received / total).clamp(0.0, 1.0) : null;
          });
        },
      );
      if (!mounted) return;
      setState(() => _downloadProgress = null);
      SmartDialog.showToast('${Intl.smb_downloadDone.tr}\n$path');
    } catch (e) {
      if (!mounted) return;
      setState(() => _downloadProgress = null);
      SmartDialog.showToast('${Intl.smb_downloadFailed.tr}: $e');
    }
  }
}
