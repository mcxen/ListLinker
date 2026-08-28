import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:file_selector/file_selector.dart';
import 'package:list_linker/database/alist_database_controller.dart';
import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/util/download/download_manager.dart';
import 'package:list_linker/util/download/download_task.dart';
import 'package:list_linker/util/download/download_task_status.dart';
import 'package:list_linker/util/named_router.dart';
import 'package:list_linker/util/user_controller.dart';
import 'package:list_linker/widget/alist_scaffold.dart';
import 'package:list_linker/widget/loading_status_widget.dart';
import 'package:list_linker/widget/overflow_text.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

class PdfReaderScreen extends StatelessWidget {
  final PdfReaderScreenController _controller =
      Get.put(PdfReaderScreenController());

  PdfReaderScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlistScaffold(
      appbarTitle: OverflowText(text: _controller.pdfItem.name),
      body: Obx(
        () => LoadingStatusWidget(
          loading: _controller.loading.value,
          retryCallback: () => _controller.retry(),
          errorMsg: _controller.errMsg.value,
          child: _buildPDFView(context),
        ),
      ),
    );
  }

  Widget _buildPDFView(BuildContext context) {
    return Obx(
      () => _controller.localPath.value.isNotEmpty
          ? GetPlatform.isDesktop
              ? _DesktopPdfEditor(path: _controller.localPath.value)
              : PDFView(
                  filePath: _controller.localPath.value,
                  autoSpacing: !Platform.isAndroid,
                  pageSnap: false,
                  enableSwipe: true,
                  pageFling: false,
                  fitEachPage: false,
                  fitPolicy: FitPolicy.WIDTH,
                  preventLinkNavigation: true,
                  onLinkHandler: (url) {
                    Get.toNamed(NamedRouter.web, arguments: {"url": url});
                  },
                  nightMode: Get.isDarkMode,
                  onError: (e) {
                    LogUtil.e(e);
                  },
                )
          : const SizedBox(),
    );
  }
}

class _DesktopPdfEditor extends StatefulWidget {
  const _DesktopPdfEditor({required this.path});

  final String path;

  @override
  State<_DesktopPdfEditor> createState() => _DesktopPdfEditorState();
}

class _DesktopPdfEditorState extends State<_DesktopPdfEditor> {
  final PdfViewerController _viewerController = PdfViewerController();
  Uint8List? _bytes;
  Object? _error;
  bool _appliedActualSize = false;

  @override
  void initState() {
    super.initState();
    _viewerController.addListener(_onViewerChanged);
    _load();
  }

  @override
  void dispose() {
    _viewerController.removeListener(_onViewerChanged);
    _viewerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  void _onViewerChanged() {
    if (_appliedActualSize || _viewerController.pageCount == 0) return;
    _appliedActualSize = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewerController.resetZoom();
    });
  }

  Future<void> _save(Uint8List bytes) async {
    try {
      await File(widget.path).writeAsBytes(bytes, flush: true);
      SmartDialog.showToast(Intl.pdfReader_saved.tr);
    } catch (error) {
      SmartDialog.showToast('${Intl.pdfReader_saveFailed.tr}: $error');
    }
  }

  Future<void> _saveAs(Uint8List bytes) async {
    final location = await getSaveLocation(
      suggestedName: p.basename(widget.path),
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (location == null) return;
    var target = location.path;
    if (p.extension(target).toLowerCase() != '.pdf') target = '$target.pdf';
    try {
      await File(target).writeAsBytes(bytes, flush: true);
      SmartDialog.showToast('${Intl.pdfReader_saved.tr}\n$target');
    } catch (error) {
      SmartDialog.showToast('${Intl.pdfReader_saveFailed.tr}: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('${Intl.pdfReader_openFailed.tr}\n$_error'),
        ),
      );
    }
    final bytes = _bytes;
    if (bytes == null) return const Center(child: CircularProgressIndicator());
    return PdfEditorView(
      key: ValueKey(widget.path),
      bytes: bytes,
      documentId: widget.path,
      viewerController: _viewerController,
      initialFit: PdfViewerFit.page,
      features: const PdfEditorFeatures(
        reflowView: false,
        pageColorEditable: false,
        flatten: false,
        colorProcessing: false,
        tools: {
          PdfEditTool.select,
          PdfEditTool.ink,
          PdfEditTool.highlight,
          PdfEditTool.eraser,
          PdfEditTool.rectangle,
          PdfEditTool.freeText,
          PdfEditTool.note,
        },
      ),
      onSave: _save,
      onSaveAs: _saveAs,
    );
  }
}

class PdfReaderScreenController extends GetxController {
  PdfItem pdfItem = Get.arguments['pdfItem'];
  StreamSubscription? _streamSubscription;
  DownloadTask? _downloadTask;
  var loading = false.obs;
  var localPath = "".obs;
  var errMsg = "".obs;

  @override
  void onInit() {
    super.onInit();
    if (pdfItem.localPath == null || pdfItem.localPath!.isEmpty) {
      AlistDatabaseController databaseController = Get.find();
      UserController userController = Get.find();
      final user = userController.user.value;
      databaseController.downloadRecordRecordDao
          .findRecordByRemotePath(
              user.serverUrl, user.username, pdfItem.remotePath)
          .then((value) {
        if (value != null && File(value.localPath).existsSync()) {
          localPath.value = value.localPath;
        } else {
          _download();
          _listenStatus();
        }
      });
    } else if (pdfItem.localPath?.isNotEmpty == true) {
      localPath.value = pdfItem.localPath!;
    }
  }

  @override
  void onClose() {
    _downloadTask?.cancel();
    _streamSubscription?.cancel();
    super.onClose();
  }

  void retry() {
    LogUtil.d("retry");
    errMsg.value = "";
    _download();
  }

  void _download() async {
    loading.value = true;

    final requestHeaders = <String, dynamic>{};
    var limitFrequency = 0;
    if (pdfItem.provider == "BaiduNetdisk") {
      requestHeaders["User-Agent"] = "pan.baidu.com";
    } else if (pdfItem.provider == "AliyundriveOpen") {
      // 阿里云盘下载请求频率限制为 1s/次
      limitFrequency = 1;
    }
    _downloadTask = await DownloadManager.instance.download(
      name: pdfItem.name,
      remotePath: pdfItem.remotePath,
      sign: pdfItem.sign ?? "",
      thumb: pdfItem.thumb,
      requestHeaders: requestHeaders,
      limitFrequency: limitFrequency,
    );
    if (_downloadTask == null) {
      errMsg.value = "Download failed.";
      loading.value = false;
      return;
    }
    if (_downloadTask?.status == DownloadTaskStatus.finished) {
      errMsg.value = "";
      loading.value = false;
      localPath.value = _downloadTask!.record.localPath;
    }
  }

  void _listenStatus() {
    _streamSubscription =
        DownloadManager.instance.listenDownloadStatusChange((task) {
      if (task != _downloadTask) {
        return;
      }
      if (task.status == DownloadTaskStatus.finished) {
        errMsg.value = "";
        loading.value = false;
        localPath.value = task.record.localPath;
      } else if (task.status == DownloadTaskStatus.failed) {
        errMsg.value = task.failedReason ?? "";
        loading.value = false;
      }
    });
  }
}

class PdfItem {
  final String name;
  String? localPath;
  final String remotePath;
  final String? sign;
  final String? provider;
  final String? thumb;

  PdfItem({
    required this.name,
    this.localPath,
    required this.remotePath,
    this.sign,
    this.provider,
    this.thumb,
  });
}
