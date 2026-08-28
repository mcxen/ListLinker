import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as date_format;
import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/screen/gallery_screen.dart';
import 'package:list_linker/screen/pdf_reader_screen.dart';
import 'package:list_linker/screen/video_player_screen.dart';
import 'package:list_linker/util/file_type.dart';
import 'package:list_linker/util/file_utils.dart';
import 'package:list_linker/util/local_file_service.dart';
import 'package:list_linker/util/named_router.dart';
import 'package:list_linker/util/video_player_util.dart';
import 'package:list_linker/widget/alist_scaffold.dart';
import 'package:list_linker/widget/app_ui.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum _FileViewMode { list, grid }

enum _SortField { name, modified, size, type }

enum _ClipboardMode { copy, move }

enum _EntryAction {
  open,
  copy,
  cut,
  duplicate,
  copyTo,
  moveTo,
  rename,
  trash,
  info,
  showHidden,
  restore,
  deleteForever,
}

/// Cross-platform local file manager for user-selected folders.
class LocalStorageBrowserScreen extends StatefulWidget {
  const LocalStorageBrowserScreen({
    super.key,
    this.embedded = false,
    this.initialPath,
  });

  final bool embedded;
  final String? initialPath;

  @override
  State<LocalStorageBrowserScreen> createState() =>
      _LocalStorageBrowserScreenState();
}

class _LocalStorageBrowserScreenState extends State<LocalStorageBrowserScreen> {
  final LocalFileService _files = LocalFileService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _keyboardFocus = FocusNode();

  String? _root;
  String _path = '';
  bool _loading = true;
  bool _busy = false;
  String? _busyLabel;
  String? _error;
  List<LocalFileEntry> _entries = const [];
  List<LocalTrashItem> _trashItems = const [];
  final List<String> _history = [];
  int _historyIndex = -1;
  final Set<String> _selected = {};
  List<String> _clipboard = const [];
  _ClipboardMode _clipboardMode = _ClipboardMode.copy;
  _FileViewMode _viewMode = _FileViewMode.list;
  _SortField _sortField = _SortField.name;
  bool _sortAscending = true;
  bool _showHidden = false;
  bool _showInfo = true;
  bool _showingTrash = false;
  String _query = '';

  bool get _usesNativeFolderPicker =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  bool get _isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  bool get _canNavigateUp =>
      !_showingTrash &&
      _root != null &&
      _path.isNotEmpty &&
      !p.equals(p.normalize(_path), p.normalize(_root!));
  bool get _canGoBack => _historyIndex > 0;
  bool get _canGoForward =>
      _historyIndex >= 0 && _historyIndex < _history.length - 1;

  List<LocalFileEntry> get _visibleEntries {
    final query = _query.trim().toLowerCase();
    final values = (_showingTrash
            ? _trashItems.map((item) => item.entry)
            : _entries)
        .where((entry) =>
            query.isEmpty || _displayName(entry).toLowerCase().contains(query))
        .toList();
    values.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      int result;
      switch (_sortField) {
        case _SortField.name:
          result = _displayName(a)
              .toLowerCase()
              .compareTo(_displayName(b).toLowerCase());
        case _SortField.modified:
          result = _entryDate(a).compareTo(_entryDate(b));
        case _SortField.size:
          result = a.size.compareTo(b.size);
        case _SortField.type:
          result = _kindLabel(a)
              .toLowerCase()
              .compareTo(_kindLabel(b).toLowerCase());
      }
      if (result == 0) {
        result = _displayName(a)
            .toLowerCase()
            .compareTo(_displayName(b).toLowerCase());
      }
      return _sortAscending ? result : -result;
    });
    return values;
  }

  List<LocalFileEntry> get _selectedEntries {
    final source =
        _showingTrash ? _trashItems.map((item) => item.entry) : _entries;
    return source.where((entry) => _selected.contains(entry.path)).toList();
  }

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map? ?? {};
    _path = widget.initialPath ?? (args['path'] as String?) ?? '';
    _root = (args['root'] as String?) ??
        (widget.initialPath?.isNotEmpty == true ? widget.initialPath : null);
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _query = _searchController.text;
        _selected.clear();
      });
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_path.isEmpty && _usesNativeFolderPicker) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (_path.isEmpty) {
      await _requestPermission();
      _path = await _resolveStartPath();
      _root ??= _path;
    }
    _recordHistory(_path);
    await _load();
  }

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid) return;
    final photos = await Permission.photos.request();
    final videos = await Permission.videos.request();
    final storage = await Permission.storage.request();
    if (photos.isDenied && videos.isDenied && storage.isDenied) {
      // App-specific directories can still be browsed.
    }
  }

  Future<String> _resolveStartPath() async {
    if (Platform.isAndroid) {
      const emulated = '/storage/emulated/0';
      if (await Directory(emulated).exists()) {
        try {
          await Directory(emulated).list(followLinks: false).take(1).toList();
          return emulated;
        } catch (_) {}
      }
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext.path;
    }
    return (await getApplicationDocumentsDirectory()).path;
  }

  Future<void> _chooseFolder() async {
    try {
      final selectedPath = await getDirectoryPath(
        initialDirectory: _path.isEmpty ? null : _path,
        confirmButtonText: Intl.localFiles_chooseFolder.tr,
      );
      if (selectedPath == null || selectedPath.isEmpty || !mounted) return;
      setState(() {
        _root = selectedPath;
        _path = selectedPath;
        _showingTrash = false;
        _selected.clear();
        _history
          ..clear()
          ..add(selectedPath);
        _historyIndex = 0;
      });
      await _load();
    } catch (error) {
      SmartDialog.showToast('${Intl.localStorage_accessDenied.tr}: $error');
    }
  }

  Future<void> _load() async {
    final root = _root;
    if (_path.isEmpty || root == null) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final entries = _showingTrash
          ? const <LocalFileEntry>[]
          : await _files.listDirectory(_path, showHidden: _showHidden);
      final trash = _showingTrash
          ? await _files.listTrash(root)
          : const <LocalTrashItem>[];
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _trashItems = trash;
        _selected.removeWhere(
          (path) =>
              !entries.any((entry) => entry.path == path) &&
              !trash.any((item) => item.entry.path == path),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFolder = _path.isNotEmpty && _root != null;
    final title = _showingTrash
        ? Intl.fileManager_trash.tr
        : hasFolder
            ? (p.basename(_path).isEmpty ? _path : p.basename(_path))
            : Intl.fileManager_title.tr;
    return AlistScaffold(
      appbarTitle: Row(
        children: [
          Flexible(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (hasFolder) ...[
            const SizedBox(width: 10),
            Text(
              Intl.fileManager_title.tr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
      appbarActions: _usesNativeFolderPicker
          ? [
              IconButton(
                onPressed: _busy ? null : _chooseFolder,
                icon: const Icon(Icons.folder_open_rounded),
                tooltip: hasFolder
                    ? Intl.localFiles_changeFolder.tr
                    : Intl.localFiles_chooseFolder.tr,
              ),
              const SizedBox(width: 8),
            ]
          : null,
      body: !hasFolder
          ? AppEmptyState(
              icon: Icons.folder_open_rounded,
              title: Intl.fileManager_title.tr,
              body: Intl.localFiles_chooseHint.tr,
              primaryAction: FilledButton.icon(
                onPressed: _chooseFolder,
                icon: const Icon(Icons.folder_open_rounded),
                label: Text(Intl.localFiles_chooseFolder.tr),
              ),
            )
          : Focus(
              focusNode: _keyboardFocus,
              autofocus: true,
              onKeyEvent: _onKeyEvent,
              child: _buildManager(context),
            ),
    );
  }

  Widget _buildManager(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildNavigationBar(context),
        Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.65)),
        _buildActionBar(context),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildFolderContents(context)),
              if (_showInfo && MediaQuery.sizeOf(context).width >= 820) ...[
                VerticalDivider(
                  width: 1,
                  color: scheme.outlineVariant.withOpacity(0.65),
                ),
                SizedBox(width: 300, child: _buildInfoPane(context)),
              ],
            ],
          ),
        ),
        _buildStatusBar(context),
      ],
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: scheme.surface,
      child: Row(
        children: [
          _toolbarIcon(
            icon: Icons.arrow_back_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _canGoBack && !_showingTrash ? _goBack : null,
          ),
          _toolbarIcon(
            icon: Icons.arrow_forward_rounded,
            tooltip: MaterialLocalizations.of(context).nextPageTooltip,
            onPressed: _canGoForward && !_showingTrash ? _goForward : null,
          ),
          _toolbarIcon(
            icon: Icons.arrow_upward_rounded,
            tooltip: 'Up',
            onPressed: _canNavigateUp ? _navigateUp : null,
          ),
          const SizedBox(width: 6),
          Expanded(child: _buildBreadcrumbs(context)),
          const SizedBox(width: 8),
          SizedBox(
            width: MediaQuery.sizeOf(context).width >= 720 ? 240 : 170,
            height: 34,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
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
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(BuildContext context) {
    final root = _root!;
    if (_showingTrash) {
      return Row(
        children: [
          Flexible(
            child: _BreadcrumbButton(
              icon: Icons.folder_special_rounded,
              label: p.basename(root).isEmpty ? root : p.basename(root),
              onTap: () => _setTrash(false),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18),
          Flexible(
            child: _BreadcrumbButton(
              icon: Icons.delete_outline_rounded,
              label: Intl.fileManager_trash.tr,
              selected: true,
              onTap: () {},
            ),
          ),
        ],
      );
    }
    final relative = p.relative(_path, from: root);
    final segments = relative == '.' ? <String>[] : p.split(relative);
    final crumbs = <({String label, String path})>[
      (
        label: p.basename(root).isEmpty ? root : p.basename(root),
        path: root,
      ),
    ];
    var current = root;
    for (final segment in segments) {
      current = p.join(current, segment);
      crumbs.add((label: segment, path: current));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          for (var index = 0; index < crumbs.length; index++) ...[
            _BreadcrumbButton(
              icon: index == 0 ? Icons.folder_special_rounded : null,
              label: crumbs[index].label,
              selected: index == crumbs.length - 1,
              onTap: () => _navigateTo(crumbs[index].path),
            ),
            if (index != crumbs.length - 1)
              const Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final hasSelection = _selected.isNotEmpty;
    final singleSelection = _selected.length == 1;
    final compact = MediaQuery.sizeOf(context).width < 930;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          if (!_showingTrash) ...[
            _toolbarButton(
              icon: Icons.create_new_folder_outlined,
              label: Intl.fileManager_newFolder.tr,
              compact: compact,
              onPressed: _busy ? null : _createFolder,
            ),
            const SizedBox(width: 4),
            _toolbarButton(
              icon: Icons.content_copy_rounded,
              label: Intl.fileManager_copy.tr,
              compact: compact,
              onPressed: hasSelection && !_busy ? _copySelection : null,
            ),
            _toolbarButton(
              icon: Icons.content_cut_rounded,
              label: Intl.fileManager_cut.tr,
              compact: compact,
              onPressed: hasSelection && !_busy ? _cutSelection : null,
            ),
            _toolbarButton(
              icon: Icons.content_paste_go_rounded,
              label: Intl.fileManager_paste.tr,
              compact: compact,
              onPressed: _clipboard.isNotEmpty && !_busy ? _paste : null,
            ),
            _toolbarButton(
              icon: Icons.drive_file_rename_outline_rounded,
              label: Intl.fileManager_rename.tr,
              compact: compact,
              onPressed: singleSelection && !_busy ? _renameSelection : null,
            ),
            _toolbarButton(
              icon: Icons.delete_outline_rounded,
              label: Intl.fileManager_moveToTrash.tr,
              compact: compact,
              onPressed: hasSelection && !_busy ? _trashSelection : null,
            ),
          ] else ...[
            _toolbarButton(
              icon: Icons.restore_rounded,
              label: Intl.fileManager_restore.tr,
              compact: compact,
              onPressed: hasSelection && !_busy ? _restoreSelection : null,
            ),
            _toolbarButton(
              icon: Icons.delete_forever_outlined,
              label: Intl.fileManager_deleteForever.tr,
              compact: compact,
              onPressed: hasSelection && !_busy ? _deleteForever : null,
            ),
            _toolbarButton(
              icon: Icons.delete_sweep_outlined,
              label: Intl.fileManager_emptyTrash.tr,
              compact: compact,
              onPressed: _trashItems.isNotEmpty && !_busy ? _emptyTrash : null,
            ),
          ],
          const Spacer(),
          if (!_showingTrash)
            PopupMenuButton<_EntryAction>(
              tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
              enabled: !_busy,
              onSelected: _handleEntryAction,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _EntryAction.duplicate,
                  enabled: hasSelection,
                  child: _menuItem(
                    Icons.control_point_duplicate_rounded,
                    Intl.fileManager_duplicate.tr,
                  ),
                ),
                PopupMenuItem(
                  value: _EntryAction.copyTo,
                  enabled: hasSelection,
                  child: _menuItem(
                    Icons.copy_all_outlined,
                    Intl.fileManager_copyTo.tr,
                  ),
                ),
                PopupMenuItem(
                  value: _EntryAction.moveTo,
                  enabled: hasSelection,
                  child: _menuItem(
                    Icons.drive_file_move_outline,
                    Intl.fileManager_moveTo.tr,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _EntryAction.showHidden,
                  child: _menuItem(
                    _showHidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    _showHidden
                        ? Intl.fileManager_hideHidden.tr
                        : Intl.fileManager_showHidden.tr,
                  ),
                ),
              ],
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          PopupMenuButton<_SortField>(
            tooltip: Intl.fileManager_sortName.tr,
            onSelected: _changeSort,
            itemBuilder: (_) => [
              _sortMenuItem(_SortField.name, Intl.fileManager_sortName.tr),
              _sortMenuItem(
                _SortField.modified,
                Intl.fileManager_sortModified.tr,
              ),
              _sortMenuItem(_SortField.size, Intl.fileManager_sortSize.tr),
              _sortMenuItem(_SortField.type, Intl.fileManager_sortType.tr),
            ],
            icon: Icon(
              _sortAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
            ),
          ),
          _toolbarIcon(
            icon: _viewMode == _FileViewMode.list
                ? Icons.grid_view_rounded
                : Icons.view_list_rounded,
            tooltip: _viewMode == _FileViewMode.list
                ? Intl.fileManager_gridView.tr
                : Intl.fileManager_listView.tr,
            onPressed: () => setState(() {
              _viewMode = _viewMode == _FileViewMode.list
                  ? _FileViewMode.grid
                  : _FileViewMode.list;
            }),
          ),
          _toolbarIcon(
            icon: _showInfo ? Icons.info_rounded : Icons.info_outline_rounded,
            tooltip: Intl.fileManager_info.tr,
            onPressed: () => setState(() => _showInfo = !_showInfo),
          ),
          _toolbarIcon(
            icon: _showingTrash
                ? Icons.folder_open_outlined
                : Icons.delete_outline_rounded,
            tooltip: _showingTrash
                ? Intl.fileManager_open.tr
                : Intl.fileManager_trash.tr,
            onPressed: () => _setTrash(!_showingTrash),
          ),
          _toolbarIcon(
            icon: Icons.refresh_rounded,
            tooltip: Intl.fileManager_refresh.tr,
            onPressed: _busy ? null : _load,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_SortField> _sortMenuItem(
    _SortField field,
    String label,
  ) {
    return PopupMenuItem(
      value: field,
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: _sortField == field
                ? Icon(
                    _sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 18,
                  )
                : null,
          ),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildFolderContents(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.folder_off_outlined,
        title: Intl.localStorage_accessDenied.tr,
        body: _error,
        primaryAction: FilledButton(
          onPressed: _load,
          child: Text(Intl.smb_retry.tr),
        ),
        secondaryAction: _usesNativeFolderPicker
            ? OutlinedButton(
                onPressed: _chooseFolder,
                child: Text(Intl.localFiles_changeFolder.tr),
              )
            : OutlinedButton(
                onPressed: openAppSettings,
                child: Text(Intl.localStorage_openSettings.tr),
              ),
      );
    }
    final entries = _visibleEntries;
    if (entries.isEmpty) {
      return AppEmptyState(
        icon: _showingTrash
            ? Icons.delete_outline_rounded
            : _query.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.folder_open_outlined,
        title: _showingTrash
            ? Intl.fileManager_trashEmpty.tr
            : _query.isNotEmpty
                ? Intl.fileManager_searchHint.tr
                : Intl.smb_folderEmpty.tr,
      );
    }
    return _viewMode == _FileViewMode.list
        ? _buildListView(context, entries)
        : _buildGridView(context, entries);
  }

  Widget _buildListView(
    BuildContext context,
    List<LocalFileEntry> entries,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final showColumns = MediaQuery.sizeOf(context).width >= 760;
    return Column(
      children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          color: scheme.surfaceContainerHighest.withOpacity(0.28),
          child: Row(
            children: [
              const SizedBox(width: 30),
              Expanded(flex: 5, child: Text(Intl.fileManager_sortName.tr)),
              if (showColumns) ...[
                Expanded(
                  flex: 2,
                  child: Text(Intl.fileManager_sortModified.tr),
                ),
                SizedBox(
                  width: 88,
                  child: Text(
                    Intl.fileManager_sortSize.tr,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(width: 105, child: Text(Intl.fileManager_sortType.tr)),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(
              bottom: 12 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            itemCount: entries.length,
            itemBuilder: (context, index) => _buildFileRow(
              context,
              entries[index],
              index,
              showColumns,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileRow(
    BuildContext context,
    LocalFileEntry entry,
    int index,
    bool showColumns,
  ) {
    final selected = _selected.contains(entry.path);
    final scheme = Theme.of(context).colorScheme;
    final cut = _clipboardMode == _ClipboardMode.move &&
        _clipboard.contains(entry.path);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) =>
          _showEntryMenu(context, details.globalPosition, entry),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withOpacity(0.6)
            : index.isEven
                ? scheme.surface
                : scheme.surfaceContainerHighest.withOpacity(0.12),
        child: InkWell(
          onTap: () => _selectEntry(entry),
          onDoubleTap: () => _openEntry(entry),
          child: Opacity(
            opacity: cut ? 0.5 : 1,
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 24,
                    child: Checkbox(
                      value: selected,
                      visualDensity: VisualDensity.compact,
                      onChanged: (_) => _toggleEntry(entry),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _entryIcon(entry, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 5,
                    child: Text(
                      _displayName(entry),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (showColumns) ...[
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatDate(_entryDate(entry)),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    SizedBox(
                      width: 88,
                      child: Text(
                        entry.isDirectory
                            ? '—'
                            : (FileUtils.formatBytes(entry.size) ?? '—'),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 105,
                      child: Text(
                        _kindLabel(entry),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridView(
    BuildContext context,
    List<LocalFileEntry> entries,
  ) {
    final paneWidth =
        _showInfo && MediaQuery.sizeOf(context).width >= 820 ? 300 : 0;
    final width = MediaQuery.sizeOf(context).width - paneWidth;
    final columns = (width / 150).floor().clamp(2, 10);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 1.15,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _buildGridTile(context, entries[index]),
    );
  }

  Widget _buildGridTile(BuildContext context, LocalFileEntry entry) {
    final selected = _selected.contains(entry.path);
    final scheme = Theme.of(context).colorScheme;
    final cut = _clipboardMode == _ClipboardMode.move &&
        _clipboard.contains(entry.path);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) =>
          _showEntryMenu(context, details.globalPosition, entry),
      child: Material(
        color: selected
            ? scheme.primaryContainer.withOpacity(0.65)
            : scheme.surfaceContainerHighest.withOpacity(0.24),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectEntry(entry),
          onDoubleTap: () => _openEntry(entry),
          child: Opacity(
            opacity: cut ? 0.5 : 1,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _entryIcon(entry, size: 48),
                      const SizedBox(height: 10),
                      Text(
                        _displayName(entry),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 4,
                  child: Checkbox(
                    value: selected,
                    visualDensity: VisualDensity.compact,
                    onChanged: (_) => _toggleEntry(entry),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPane(BuildContext context) {
    final selected = _selectedEntries;
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest.withOpacity(0.16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        child: selected.isEmpty
            ? Column(
                children: [
                  const SizedBox(height: 48),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 42,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    Intl.fileManager_info.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_visibleEntries.length} ${Intl.fileManager_items.tr}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              )
            : selected.length == 1
                ? _buildSingleInfo(context, selected.single)
                : _buildMultiInfo(context, selected),
      ),
    );
  }

  Widget _buildSingleInfo(BuildContext context, LocalFileEntry entry) {
    final trashItem = _trashItemFor(entry.path);
    final type = FileUtils.getFileType(entry.isDirectory, _displayName(entry));
    final canPreviewImage =
        entry.isFile && type == FileType.image && !_showingTrash;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canPreviewImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(
                File(entry.path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: _entryIcon(entry, size: 72),
                ),
              ),
            ),
          )
        else
          Center(child: _entryIcon(entry, size: 76)),
        const SizedBox(height: 18),
        SelectableText(
          _displayName(entry),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 22),
        _infoLine(context, Intl.fileManager_sortType.tr, _kindLabel(entry)),
        _infoLine(
          context,
          Intl.fileManager_sortSize.tr,
          entry.isDirectory ? '—' : (FileUtils.formatBytes(entry.size) ?? '—'),
        ),
        _infoLine(
          context,
          Intl.fileManager_sortModified.tr,
          _formatDate(entry.modified, includeYear: true),
        ),
        _infoLine(
          context,
          Intl.fileManager_location.tr,
          trashItem?.originalPath ?? entry.path,
          selectable: true,
        ),
        if (trashItem != null)
          _infoLine(
            context,
            Intl.fileManager_deletedAt.tr,
            _formatDate(trashItem.deletedAt, includeYear: true),
          ),
        const SizedBox(height: 18),
        if (_showingTrash)
          FilledButton.icon(
            onPressed: _busy ? null : _restoreSelection,
            icon: const Icon(Icons.restore_rounded),
            label: Text(Intl.fileManager_restore.tr),
          )
        else
          FilledButton.icon(
            onPressed: () => _openEntry(entry),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(Intl.fileManager_open.tr),
          ),
      ],
    );
  }

  Widget _buildMultiInfo(
    BuildContext context,
    List<LocalFileEntry> selected,
  ) {
    final totalSize = selected.fold<int>(0, (sum, entry) => sum + entry.size);
    return Column(
      children: [
        const SizedBox(height: 30),
        const Icon(Icons.library_add_check_rounded, size: 68),
        const SizedBox(height: 16),
        Text(
          '${selected.length} ${Intl.fileManager_selected.tr}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(FileUtils.formatBytes(totalSize) ?? '—'),
      ],
    );
  }

  Widget _infoLine(
    BuildContext context,
    String label,
    String value, {
    bool selectable = false,
  }) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: style),
          const SizedBox(height: 3),
          if (selectable)
            SelectableText(value, style: Theme.of(context).textTheme.bodyMedium)
          else
            Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedSize = _selectedEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.size,
    );
    final selectionText = _selected.isEmpty
        ? ''
        : ' · ${_selected.length} ${Intl.fileManager_selected.tr}'
            '${selectedSize > 0 ? ' · ${FileUtils.formatBytes(selectedSize)}' : ''}';
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.24),
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${_visibleEntries.length} ${Intl.fileManager_items.tr}$selectionText',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          if (_busyLabel != null)
            Flexible(
              child: Text(
                _busyLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else if (_clipboard.isNotEmpty)
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _clipboardMode == _ClipboardMode.copy
                        ? Icons.content_copy_rounded
                        : Icons.content_cut_rounded,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_clipboard.length} · ${Intl.fileManager_clipboardReady.tr}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _entryIcon(LocalFileEntry entry, {required double size}) {
    return Image.asset(
      FileUtils.getFileIcon(entry.isDirectory, _displayName(entry)),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        entry.isDirectory ? Icons.folder_rounded : Icons.insert_drive_file,
        size: size,
      ),
    );
  }

  Widget _toolbarIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    required bool compact,
    required VoidCallback? onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: compact ? const SizedBox.shrink() : Text(label),
      style: compact
          ? TextButton.styleFrom(
              minimumSize: const Size(38, 36),
              padding: const EdgeInsets.symmetric(horizontal: 9),
            )
          : null,
    );
  }

  Widget _menuItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }

  Future<void> _showEntryMenu(
    BuildContext context,
    Offset position,
    LocalFileEntry entry,
  ) async {
    if (!_selected.contains(entry.path)) {
      setState(() {
        _selected
          ..clear()
          ..add(entry.path);
      });
    }
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<_EntryAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(position, position),
        Offset.zero & overlay.size,
      ),
      items: _showingTrash
          ? [
              PopupMenuItem(
                value: _EntryAction.restore,
                child: _menuItem(
                  Icons.restore_rounded,
                  Intl.fileManager_restore.tr,
                ),
              ),
              PopupMenuItem(
                value: _EntryAction.deleteForever,
                child: _menuItem(
                  Icons.delete_forever_outlined,
                  Intl.fileManager_deleteForever.tr,
                ),
              ),
              PopupMenuItem(
                value: _EntryAction.info,
                child: _menuItem(
                  Icons.info_outline_rounded,
                  Intl.fileManager_info.tr,
                ),
              ),
            ]
          : [
              PopupMenuItem(
                value: _EntryAction.open,
                child: _menuItem(
                  Icons.open_in_new_rounded,
                  Intl.fileManager_open.tr,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _EntryAction.copy,
                child: _menuItem(
                  Icons.content_copy_rounded,
                  Intl.fileManager_copy.tr,
                ),
              ),
              PopupMenuItem(
                value: _EntryAction.cut,
                child: _menuItem(
                  Icons.content_cut_rounded,
                  Intl.fileManager_cut.tr,
                ),
              ),
              PopupMenuItem(
                value: _EntryAction.duplicate,
                child: _menuItem(
                  Icons.control_point_duplicate_rounded,
                  Intl.fileManager_duplicate.tr,
                ),
              ),
              PopupMenuItem(
                value: _EntryAction.copyTo,
                child: _menuItem(
                  Icons.copy_all_outlined,
                  Intl.fileManager_copyTo.tr,
                ),
              ),
              PopupMenuItem(
                value: _EntryAction.moveTo,
                child: _menuItem(
                  Icons.drive_file_move_outline,
                  Intl.fileManager_moveTo.tr,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _EntryAction.rename,
                enabled: _selected.length == 1,
                child: _menuItem(
                  Icons.drive_file_rename_outline_rounded,
                  Intl.fileManager_rename.tr,
                ),
              ),
              PopupMenuItem(
                value: _EntryAction.trash,
                child: _menuItem(
                  Icons.delete_outline_rounded,
                  Intl.fileManager_moveToTrash.tr,
                ),
              ),
              PopupMenuItem(
                value: _EntryAction.info,
                child: _menuItem(
                  Icons.info_outline_rounded,
                  Intl.fileManager_info.tr,
                ),
              ),
            ],
    );
    if (action != null) _handleEntryAction(action);
  }

  void _handleEntryAction(_EntryAction action) {
    switch (action) {
      case _EntryAction.open:
        if (_selectedEntries.length == 1) _openEntry(_selectedEntries.single);
      case _EntryAction.copy:
        _copySelection();
      case _EntryAction.cut:
        _cutSelection();
      case _EntryAction.duplicate:
        _duplicateSelection();
      case _EntryAction.copyTo:
        _copyOrMoveTo(move: false);
      case _EntryAction.moveTo:
        _copyOrMoveTo(move: true);
      case _EntryAction.rename:
        _renameSelection();
      case _EntryAction.trash:
        _trashSelection();
      case _EntryAction.info:
        setState(() => _showInfo = true);
      case _EntryAction.showHidden:
        setState(() => _showHidden = !_showHidden);
        _load();
      case _EntryAction.restore:
        _restoreSelection();
      case _EntryAction.deleteForever:
        _deleteForever();
    }
  }

  void _selectEntry(LocalFileEntry entry) {
    final keyboard = HardwareKeyboard.instance;
    final additive = keyboard.isMetaPressed || keyboard.isControlPressed;
    if (_isDesktop) {
      setState(() {
        if (additive) {
          _selected.contains(entry.path)
              ? _selected.remove(entry.path)
              : _selected.add(entry.path);
        } else {
          _selected
            ..clear()
            ..add(entry.path);
        }
      });
    } else {
      _openEntry(entry);
    }
  }

  void _toggleEntry(LocalFileEntry entry) {
    setState(() {
      _selected.contains(entry.path)
          ? _selected.remove(entry.path)
          : _selected.add(entry.path);
    });
  }

  Future<void> _openEntry(LocalFileEntry entry) async {
    if (_showingTrash) return;
    if (entry.isDirectory) {
      await _navigateTo(entry.path);
      return;
    }
    final fileType = FileUtils.getFileType(false, entry.name);
    if (fileType == FileType.image) {
      final images = _entries
          .where((item) =>
              item.isFile &&
              FileUtils.getFileType(false, item.name) == FileType.image)
          .map(
            (item) => PhotoItem(
              name: item.name,
              localPath: item.path,
              remotePath: item.path,
              sign: '',
              provider: 'Local',
            ),
          )
          .toList();
      final index = images.indexWhere((image) => image.localPath == entry.path);
      if (index >= 0) {
        Get.toNamed(
          NamedRouter.gallery,
          arguments: {'files': images, 'index': index},
        );
      }
      return;
    }
    if (fileType == FileType.pdf) {
      Get.toNamed(
        NamedRouter.pdfReader,
        arguments: {
          'pdfItem': PdfItem(
            name: entry.name,
            localPath: entry.path,
            remotePath: entry.path,
            sign: '',
            provider: 'Local',
          ),
        },
      );
      return;
    }
    if (fileType != FileType.video) {
      final result = await OpenFile.open(entry.path);
      if (result.type != ResultType.done) SmartDialog.showToast(result.message);
      return;
    }
    final videos = _entries
        .where((item) =>
            item.isFile &&
            FileUtils.getFileType(false, item.name) == FileType.video)
        .map(
          (item) => VideoItem(
            name: item.name,
            localPath: item.path,
            remotePath: item.path,
            sign: '',
            provider: 'Local',
            thumb: null,
            size: item.size,
            modifiedMilliseconds: item.modified.millisecondsSinceEpoch,
          ),
        )
        .toList();
    final index = videos.indexWhere((video) => video.localPath == entry.path);
    if (index >= 0) VideoPlayerUtil.go(videos, index, null);
  }

  Future<void> _navigateTo(String target) async {
    if (_showingTrash || p.equals(target, _path)) return;
    final normalized = p.normalize(target);
    final normalizedRoot = p.normalize(_root!);
    if (!p.equals(normalized, normalizedRoot) &&
        !p.isWithin(normalizedRoot, normalized)) {
      return;
    }
    setState(() {
      _path = target;
      _selected.clear();
      _recordHistory(target);
    });
    await _load();
  }

  void _recordHistory(String path) {
    if (_historyIndex >= 0 &&
        _historyIndex < _history.length &&
        p.equals(_history[_historyIndex], path)) {
      return;
    }
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(path);
    _historyIndex = _history.length - 1;
  }

  Future<void> _goBack() async {
    if (!_canGoBack) return;
    setState(() {
      _historyIndex--;
      _path = _history[_historyIndex];
      _selected.clear();
    });
    await _load();
  }

  Future<void> _goForward() async {
    if (!_canGoForward) return;
    setState(() {
      _historyIndex++;
      _path = _history[_historyIndex];
      _selected.clear();
    });
    await _load();
  }

  Future<void> _navigateUp() async {
    if (_canNavigateUp) await _navigateTo(p.dirname(_path));
  }

  void _setTrash(bool value) {
    _searchController.clear();
    setState(() {
      _showingTrash = value;
      _selected.clear();
    });
    _load();
  }

  void _changeSort(_SortField field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortField = field;
        _sortAscending = true;
      }
    });
  }

  Future<void> _createFolder() async {
    final name = await _askName(
      title: Intl.fileManager_newFolder.tr,
      initialValue: '',
      confirmLabel: Intl.fileManager_create.tr,
    );
    if (name != null) {
      await _runOperation(() => _files.createFolder(_path, name));
    }
  }

  Future<void> _renameSelection() async {
    final selected = _selectedEntries;
    if (selected.length != 1 || _showingTrash) return;
    final entry = selected.single;
    final name = await _askName(
      title: Intl.fileManager_rename.tr,
      initialValue: entry.name,
      confirmLabel: Intl.fileManager_rename.tr,
    );
    if (name == null || name == entry.name) return;
    await _runOperation(() async {
      final renamed = await _files.renameEntry(entry.path, name);
      _selected
        ..clear()
        ..add(renamed);
    });
  }

  void _copySelection() {
    if (_selected.isEmpty || _showingTrash) return;
    setState(() {
      _clipboard = List<String>.from(_selected);
      _clipboardMode = _ClipboardMode.copy;
    });
    SmartDialog.showToast(Intl.fileManager_clipboardReady.tr);
  }

  void _cutSelection() {
    if (_selected.isEmpty || _showingTrash) return;
    setState(() {
      _clipboard = List<String>.from(_selected);
      _clipboardMode = _ClipboardMode.move;
    });
    SmartDialog.showToast(Intl.fileManager_clipboardReady.tr);
  }

  Future<void> _paste() async {
    if (_clipboard.isEmpty || _showingTrash) return;
    final sources = List<String>.from(_clipboard);
    if (_clipboardMode == _ClipboardMode.move) {
      final movable = sources
          .where((source) => !p.equals(p.dirname(source), _path))
          .toList();
      if (movable.isEmpty) return;
      await _runOperation(() async {
        await _files.moveEntries(movable, _path);
        _clipboard = const [];
      });
    } else {
      await _runOperation(() => _files.copyEntries(sources, _path));
    }
  }

  Future<void> _duplicateSelection() async {
    if (_selected.isEmpty || _showingTrash) return;
    await _runOperation(() => _files.duplicateEntries(_selected));
  }

  Future<void> _copyOrMoveTo({required bool move}) async {
    if (_selected.isEmpty || _showingTrash) return;
    final destination = await getDirectoryPath(
      initialDirectory: _path,
      confirmButtonText:
          move ? Intl.fileManager_moveTo.tr : Intl.fileManager_copyTo.tr,
    );
    if (destination == null || destination.isEmpty) return;
    final sources = List<String>.from(_selected);
    await _runOperation(() async {
      if (move) {
        await _files.moveEntries(sources, destination);
      } else {
        await _files.copyEntries(sources, destination);
      }
    });
  }

  Future<void> _trashSelection() async {
    if (_selected.isEmpty || _showingTrash) return;
    final confirmed = await _confirm(
      title: Intl.fileManager_confirmTrashTitle.tr,
      body: Intl.fileManager_confirmTrashBody.tr,
      confirmLabel: Intl.fileManager_moveToTrash.tr,
    );
    if (!confirmed) return;
    final sources = List<String>.from(_selected);
    await _runOperation(() => _files.moveToTrash(sources, _root!));
  }

  Future<void> _restoreSelection() async {
    final selectedItems = _trashItems
        .where((item) => _selected.contains(item.entry.path))
        .toList();
    if (selectedItems.isEmpty) return;
    await _runOperation(() async {
      for (final item in selectedItems) {
        await _files.restoreTrashItem(item, _root!);
      }
    });
  }

  Future<void> _deleteForever() async {
    final selectedItems = _trashItems
        .where((item) => _selected.contains(item.entry.path))
        .toList();
    if (selectedItems.isEmpty) return;
    final confirmed = await _confirm(
      title: Intl.fileManager_confirmDeleteTitle.tr,
      body: Intl.fileManager_confirmDeleteBody.tr,
    );
    if (!confirmed) return;
    await _runOperation(
      () => _files.deleteTrashItems(selectedItems, _root!),
    );
  }

  Future<void> _emptyTrash() async {
    final confirmed = await _confirm(
      title: Intl.fileManager_emptyTrash.tr,
      body: Intl.fileManager_confirmEmptyTrash.tr,
    );
    if (!confirmed) return;
    await _runOperation(() => _files.emptyTrash(_root!));
  }

  Future<void> _runOperation(Future<dynamic> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyLabel = Intl.fileManager_operationDone.tr;
    });
    try {
      await operation();
      if (!mounted) return;
      setState(() => _selected.clear());
      await _load();
      SmartDialog.showToast(Intl.fileManager_operationDone.tr);
    } catch (error) {
      SmartDialog.showToast('${Intl.fileManager_operationFailed.tr}: $error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<String?> _askName({
    required String title,
    required String initialValue,
    required String confirmLabel,
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
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result?.trim().isEmpty == true ? null : result?.trim();
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    String? confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
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
                child: Text(confirmLabel ?? Intl.deleteFileDialog_btn_ok.tr),
              ),
            ],
          ),
        ) ??
        false;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _busy) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final command = keyboard.isMetaPressed || keyboard.isControlPressed;
    if (command && key == LogicalKeyboardKey.keyA) {
      setState(() {
        _selected
          ..clear()
          ..addAll(_visibleEntries.map((entry) => entry.path));
      });
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyC) {
      _copySelection();
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyX) {
      _cutSelection();
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyV) {
      _paste();
      return KeyEventResult.handled;
    }
    if (command && key == LogicalKeyboardKey.keyF) {
      _searchFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (command && keyboard.isShiftPressed && key == LogicalKeyboardKey.keyN) {
      _createFolder();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f2) {
      if (_selected.length == 1) _renameSelection();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && _selected.length == 1) {
      _openEntry(_selectedEntries.single);
      return KeyEventResult.handled;
    }
    if ((Platform.isMacOS &&
            keyboard.isMetaPressed &&
            key == LogicalKeyboardKey.backspace) ||
        (!Platform.isMacOS && key == LogicalKeyboardKey.delete)) {
      _showingTrash ? _deleteForever() : _trashSelection();
      return KeyEventResult.handled;
    }
    if (keyboard.isAltPressed && key == LogicalKeyboardKey.arrowLeft) {
      _goBack();
      return KeyEventResult.handled;
    }
    if (keyboard.isAltPressed && key == LogicalKeyboardKey.arrowRight) {
      _goForward();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_query.isNotEmpty) {
        _searchController.clear();
      } else {
        setState(() => _selected.clear());
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _displayName(LocalFileEntry entry) {
    final trashItem = _trashItemFor(entry.path);
    return trashItem == null ? entry.name : p.basename(trashItem.originalPath);
  }

  LocalTrashItem? _trashItemFor(String path) {
    for (final item in _trashItems) {
      if (item.entry.path == path) return item;
    }
    return null;
  }

  DateTime _entryDate(LocalFileEntry entry) {
    return _trashItemFor(entry.path)?.deletedAt ?? entry.modified;
  }

  String _kindLabel(LocalFileEntry entry) {
    if (entry.isDirectory) return Intl.fileManager_folder.tr;
    final extension = p.extension(_displayName(entry));
    return extension.isEmpty
        ? Intl.fileManager_file.tr
        : '${extension.substring(1).toUpperCase()} ${Intl.fileManager_file.tr}';
  }

  String _formatDate(DateTime date, {bool includeYear = false}) {
    final pattern = includeYear || date.year != DateTime.now().year
        ? 'yyyy/MM/dd HH:mm'
        : 'MM/dd HH:mm';
    return date_format.DateFormat(pattern).format(date.toLocal());
  }
}

class _BreadcrumbButton extends StatelessWidget {
  const _BreadcrumbButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.surfaceContainerHighest.withOpacity(0.6)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: scheme.primary),
                const SizedBox(width: 5),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
