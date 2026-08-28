import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:list_linker/generated/images.dart';
import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/screen/gallery_screen.dart';
import 'package:list_linker/screen/pdf_reader_screen.dart';
import 'package:list_linker/screen/video_player_screen.dart';
import 'package:list_linker/util/file_type.dart';
import 'package:list_linker/util/file_utils.dart';
import 'package:list_linker/util/named_router.dart';
import 'package:list_linker/util/smb/smb_service.dart';
import 'package:list_linker/util/video_player_util.dart';
import 'package:list_linker/widget/alist_scaffold.dart';
import 'package:list_linker/widget/app_ui.dart';
import 'package:list_linker/widget/file_list_item_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

/// Browse an SMB share / folder, play videos, and download files.
class SmbBrowserScreen extends StatefulWidget {
  const SmbBrowserScreen({
    super.key,
    this.initialPath,
    this.connectionTitle,
    this.embedded = false,
    this.onClose,
  });

  final String? initialPath;
  final String? connectionTitle;
  final bool embedded;
  final VoidCallback? onClose;

  @override
  State<SmbBrowserScreen> createState() => _SmbBrowserScreenState();
}

class _SmbBrowserScreenState extends State<SmbBrowserScreen> {
  final SmbService _smb = Get.find();
  final TextEditingController _searchController = TextEditingController();
  late String _path;
  late String _rootPath;
  late String _title;
  bool _loading = true;
  String? _error;
  List<SmbFile> _files = [];
  double? _downloadProgress;
  double? _uploadProgress;
  String _query = '';

  List<SmbFile> get _visibleFiles {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _files;
    return _files
        .where((file) => file.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map? ?? {};
    _path = widget.initialPath ?? (args['path'] as String?) ?? '';
    _rootPath = _path;
    _title = widget.connectionTitle ??
        (args['title'] as String?) ??
        Intl.screenName_smb.tr;
    _searchController.addListener(() {
      if (mounted) setState(() => _query = _searchController.text);
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final displayTitle =
        _path.isEmpty ? _title : (parts.isEmpty ? _title : parts.last);
    final scheme = Theme.of(context).colorScheme;

    return AlistScaffold(
      appbarTitle: Text(displayTitle),
      appbarLeading: widget.embedded
          ? IconButton(
              onPressed: _navigateBack,
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            )
          : null,
      body: Column(
        children: [
          _buildToolbar(context),
          Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.6)),
          Expanded(
            child: Stack(
              children: [
                _buildContent(context),
                if (_downloadProgress != null || _uploadProgress != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12 + MediaQuery.viewPaddingOf(context).bottom,
                    child: _buildProgressCard(context),
                  ),
              ],
            ),
          ),
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            color: scheme.surfaceContainerHighest.withOpacity(0.25),
            child: Text(
              '${_visibleFiles.length} ${Intl.fileManager_items.tr} · SMB',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          Icon(Icons.dns_outlined, size: 19, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _path.isEmpty ? _title : '$_title  ›  ${_path.substring(1)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (_path.isNotEmpty) ...[
            IconButton(
              tooltip: Intl.fileManager_newFolder.tr,
              onPressed: _createFolder,
              icon: const Icon(Icons.create_new_folder_outlined, size: 20),
            ),
            IconButton(
              tooltip: Intl.fileList_menu_uploadFiles.tr,
              onPressed: _uploadFiles,
              icon: const Icon(Icons.upload_file_outlined, size: 20),
            ),
          ],
          SizedBox(
            width: MediaQuery.sizeOf(context).width >= 760 ? 230 : 160,
            height: 34,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: Intl.fileManager_searchHint.tr,
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withOpacity(0.55),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: Intl.fileManager_refresh.tr,
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: Intl.smb_connectFailed.tr,
        body: _error,
        primaryAction: FilledButton(
          onPressed: _load,
          child: Text(Intl.smb_retry.tr),
        ),
      );
    }
    final files = _visibleFiles;
    if (files.isEmpty) {
      return AppEmptyState(
        icon: _query.isEmpty
            ? Icons.folder_off_outlined
            : Icons.search_off_rounded,
        title: _query.isEmpty
            ? Intl.smb_folderEmpty.tr
            : Intl.fileManager_searchHint.tr,
      );
    }
    return ListView.separated(
      padding: EdgeInsets.only(
        bottom:
            (_downloadProgress != null || _uploadProgress != null ? 88 : 16) +
                MediaQuery.viewPaddingOf(context).bottom,
      ),
      itemCount: files.length,
      separatorBuilder: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Divider(height: 1, thickness: 0.6),
      ),
      itemBuilder: (context, index) {
        final file = files[index];
        final isDir = file.isDirectory() || _path.isEmpty;
        final icon = isDir
            ? Images.fileTypeFolder
            : FileUtils.getFileIcon(false, file.name);
        return FileListItemView(
          icon: icon,
          fileName: file.name,
          time: null,
          sizeDesc: isDir ? null : FileUtils.formatBytes(file.size),
          onTap: () => _onTap(file, isDir),
          onMoreIconButtonTap:
              _path.isEmpty ? null : () => _showFileActions(file),
        );
      },
    );
  }

  Widget _buildProgressCard(BuildContext context) {
    final progress = _uploadProgress ?? _downloadProgress;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppUi.radius),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _uploadProgress != null
                  ? Intl.fileList_menu_uploadFiles.tr
                  : Intl.smb_downloading.tr,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(minHeight: 6, value: progress),
            ),
          ],
        ),
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
      if (widget.embedded) {
        setState(() => _path = nextPath);
        await _load();
        return;
      }
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
    if (type == FileType.image || type == FileType.pdf) {
      await _previewFile(file);
      return;
    }
    await _showFileActions(file);
  }

  void _navigateBack() {
    if (_path == _rootPath) {
      widget.onClose?.call();
      return;
    }
    final parts = _path.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isNotEmpty) parts.removeLast();
    final parent = parts.isEmpty ? '' : '/${parts.join('/')}';
    if (_rootPath.isNotEmpty && parent.length < _rootPath.length) {
      _path = _rootPath;
    } else {
      _path = parent;
    }
    _load();
  }

  Future<void> _showFileActions(SmbFile file) async {
    final fileType = FileUtils.getFileType(false, file.name);
    final isVideo = fileType == FileType.video;
    final isPreviewable =
        fileType == FileType.image || fileType == FileType.pdf;
    final isDirectory = file.isDirectory();
    await showAppBottomSheet(
      context: context,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: AppListTile(
            leadingIcon: isDirectory
                ? Icons.folder_outlined
                : isVideo
                    ? Icons.movie_outlined
                    : Icons.insert_drive_file_outlined,
            title: file.name,
            subtitle: isDirectory
                ? Intl.fileManager_folder.tr
                : FileUtils.formatBytes(file.size),
          ),
        ),
        const AppInsetDivider(),
        if (isVideo)
          AppListTile(
            leadingIcon: Icons.play_arrow_rounded,
            title: Intl.smb_action_play.tr,
            onTap: () {
              Navigator.pop(context);
              _playVideo(file);
            },
          ),
        if (isPreviewable)
          AppListTile(
            leadingIcon: Icons.visibility_outlined,
            title: Intl.fileManager_open.tr,
            onTap: () {
              Navigator.pop(context);
              _previewFile(file);
            },
          ),
        if (!isDirectory)
          AppListTile(
            leadingIcon: Icons.download_rounded,
            title: Intl.smb_action_download.tr,
            onTap: () {
              Navigator.pop(context);
              _download(file);
            },
          ),
        AppListTile(
          leadingIcon: Icons.drive_file_rename_outline_rounded,
          title: Intl.fileManager_rename.tr,
          onTap: () {
            Navigator.pop(context);
            _rename(file);
          },
        ),
        AppListTile(
          leadingIcon: Icons.delete_outline_rounded,
          title: Intl.fileManager_deleteForever.tr,
          onTap: () {
            Navigator.pop(context);
            _delete(file);
          },
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Future<void> _createFolder() async {
    final name = await _askName(
      title: Intl.fileManager_newFolder.tr,
      initialValue: '',
    );
    if (name == null) return;
    await _runRemoteOperation(
      () => _smb.createFolder(p.posix.join(_path, name)),
    );
  }

  Future<void> _rename(SmbFile file) async {
    final name = await _askName(
      title: Intl.fileManager_rename.tr,
      initialValue: file.name,
    );
    if (name == null || name == file.name) return;
    await _runRemoteOperation(
      () => _smb.rename(file, p.posix.join(_path, name)),
    );
  }

  Future<void> _delete(SmbFile file) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(Intl.fileManager_confirmDeleteTitle.tr),
            content: Text(
              '${file.name}\n${Intl.fileManager_confirmDeleteBody.tr}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(Intl.deleteFileDialog_btn_cancel.tr),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(Intl.deleteFileDialog_btn_ok.tr),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _runRemoteOperation(() => _smb.delete(file));
  }

  Future<void> _uploadFiles() async {
    final picked = await openFiles(
      confirmButtonText: Intl.fileList_menu_uploadFiles.tr,
    );
    if (picked.isEmpty) return;
    try {
      for (final pickedFile in picked) {
        if (!mounted) return;
        setState(() => _uploadProgress = 0);
        await _smb.uploadFile(
          File(pickedFile.path),
          _path,
          onProgress: (sent, total) {
            if (!mounted) return;
            setState(() {
              _uploadProgress =
                  total > 0 ? (sent / total).clamp(0.0, 1.0) : null;
            });
          },
        );
      }
      if (!mounted) return;
      setState(() => _uploadProgress = null);
      await _load();
      SmartDialog.showToast(Intl.fileManager_operationDone.tr);
    } catch (error) {
      if (mounted) setState(() => _uploadProgress = null);
      SmartDialog.showToast('${Intl.fileManager_operationFailed.tr}: $error');
    }
  }

  Future<void> _runRemoteOperation(
    Future<dynamic> Function() operation,
  ) async {
    SmartDialog.showLoading();
    try {
      await operation();
      SmartDialog.dismiss();
      await _load();
      SmartDialog.showToast(Intl.fileManager_operationDone.tr);
    } catch (error) {
      SmartDialog.dismiss();
      SmartDialog.showToast('${Intl.fileManager_operationFailed.tr}: $error');
    }
  }

  Future<String?> _askName({
    required String title,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: initialValue.isEmpty
          ? 0
          : initialValue.length - p.extension(initialValue).length,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: Intl.fileManager_nameHint.tr),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Intl.fileRenameDialog_btn_cancel.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(Intl.fileRenameDialog_btn_ok.tr),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.trim().isEmpty == true ? null : result?.trim();
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
    final path = await _downloadToLocal(file);
    if (path != null) {
      SmartDialog.showToast('${Intl.smb_downloadDone.tr}\n$path');
    }
  }

  Future<String?> _downloadToLocal(SmbFile file) async {
    if (file.isDirectory()) return null;
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
      if (!mounted) return null;
      setState(() => _downloadProgress = null);
      return path;
    } catch (e) {
      if (!mounted) return null;
      setState(() => _downloadProgress = null);
      SmartDialog.showToast('${Intl.smb_downloadFailed.tr}: $e');
      return null;
    }
  }

  Future<void> _previewFile(SmbFile file) async {
    final path = await _downloadToLocal(file);
    if (path == null) return;
    final type = FileUtils.getFileType(false, file.name);
    if (type == FileType.image) {
      Get.toNamed(
        NamedRouter.gallery,
        arguments: {
          'files': [
            PhotoItem(
              name: file.name,
              localPath: path,
              remotePath: file.path,
              sign: '',
              provider: 'SMB',
            ),
          ],
          'index': 0,
        },
      );
      return;
    }
    if (type == FileType.pdf) {
      Get.toNamed(
        NamedRouter.pdfReader,
        arguments: {
          'pdfItem': PdfItem(
            name: file.name,
            localPath: path,
            remotePath: file.path,
            sign: '',
            provider: 'SMB',
          ),
        },
      );
    }
  }
}
