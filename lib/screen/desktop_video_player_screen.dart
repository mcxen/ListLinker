import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/screen/video_player_screen.dart';
import 'package:list_linker/util/file_utils.dart';
import 'package:list_linker/util/proxy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Desktop-native video player for macOS, Windows and Linux.
///
/// The mobile player is backed by AliPlayer. Desktop uses media_kit/libmpv so
/// local paths and SMB proxy URLs are decoded by an actual desktop backend.
class DesktopVideoPlayerScreen extends StatefulWidget {
  const DesktopVideoPlayerScreen({super.key});

  @override
  State<DesktopVideoPlayerScreen> createState() =>
      _DesktopVideoPlayerScreenState();
}

class _DesktopVideoPlayerScreenState extends State<DesktopVideoPlayerScreen> {
  static const MethodChannel _videoCommandChannel = MethodChannel(
    'com.github.listlinker.client/video_commands',
  );

  final List<VideoItem> _videos = Get.arguments['videos'];
  late int _index = Get.arguments['index'] ?? 0;
  final Player _player = Player();
  late final VideoController _videoController = VideoController(_player);
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();
  final FocusNode _focusNode = FocusNode(debugLabel: 'desktop-video-player');
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  bool _playing = false;
  bool _buffering = true;
  bool _opening = true;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  double _volume = 100;
  double _rate = 1;
  String? _error;
  Timer? _hideTimer;
  Timer? _captureNoticeTimer;
  bool _proxyStarted = false;
  bool _capturingFrame = false;
  bool _generatingContactSheet = false;
  bool _captureFailed = false;
  String? _captureNotice;
  String? _capturePath;

  VideoItem get _current => _videos[_index];
  bool get _captureBusy => _capturingFrame || _generatingContactSheet;

  @override
  void initState() {
    super.initState();
    if (Platform.isMacOS) {
      _videoCommandChannel.setMethodCallHandler(_handleVideoCommand);
      unawaited(
        _videoCommandChannel.invokeMethod<void>(
          'setCaptureShortcutEnabled',
          true,
        ),
      );
    }
    _bindPlayerState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _openCurrent();
    });
  }

  Future<void> _handleVideoCommand(MethodCall call) async {
    if (call.method == 'captureCurrentFrame') {
      await _captureCurrentFrame();
    }
  }

  void _bindPlayerState() {
    _subscriptions.addAll([
      _player.stream.position.listen((value) {
        if (!mounted) return;
        setState(() => _position = value);
      }),
      _player.stream.duration.listen((value) {
        if (!mounted) return;
        setState(() => _duration = value);
      }),
      _player.stream.buffer.listen((value) {
        if (!mounted) return;
        setState(() => _buffer = value);
      }),
      _player.stream.playing.listen((value) {
        if (!mounted) return;
        setState(() {
          _playing = value;
          if (!value) _controlsVisible = true;
        });
        if (value) {
          _scheduleControlsHide();
        } else {
          _hideTimer?.cancel();
        }
      }),
      _player.stream.buffering.listen((value) {
        if (!mounted) return;
        setState(() => _buffering = value);
      }),
      _player.stream.volume.listen((value) {
        if (!mounted) return;
        setState(() => _volume = value);
      }),
      _player.stream.rate.listen((value) {
        if (!mounted) return;
        setState(() => _rate = value);
      }),
      _player.stream.error.listen((value) {
        if (!mounted || value.trim().isEmpty) return;
        setState(() {
          _error = value;
          _opening = false;
          _controlsVisible = true;
        });
      }),
      _player.stream.completed.listen((value) {
        if (value && _index < _videos.length - 1) {
          _playAt(_index + 1);
        }
      }),
    ]);
  }

  Future<String?> _resolveSource(VideoItem item) async {
    final localPath = item.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      if (localPath.startsWith('http://') ||
          localPath.startsWith('https://') ||
          localPath.startsWith('file://')) {
        return localPath;
      }
      final file = File(localPath);
      if (!await file.exists()) {
        throw FileSystemException('File not found', localPath);
      }
      return Uri.file(file.path).toString();
    }

    if (item.playUrl?.isNotEmpty == true) return item.playUrl;

    final target = await FileUtils.makeFileLink(item.remotePath, item.sign);
    if (target == null || target.isEmpty) return null;
    if (item.provider == 'BaiduNetdisk') {
      final proxy = Get.find<ProxyServer>();
      await proxy.start();
      _proxyStarted = true;
      return proxy.makeProxyUrl(
        target,
        headers: {HttpHeaders.userAgentHeader: 'pan.baidu.com'},
      ).toString();
    }
    return target;
  }

  Future<void> _openCurrent() async {
    setState(() {
      _opening = true;
      _buffering = true;
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _buffer = Duration.zero;
      _controlsVisible = true;
    });
    try {
      final source = await _resolveSource(_current);
      if (source == null) {
        throw StateError(Intl.tips_request_raw_url_failed.tr);
      }
      await _player.open(
        Media(source, extras: {'title': _displayTitle(_current.name)}),
        play: true,
      );
      if (!mounted) return;
      setState(() => _opening = false);
      _scheduleControlsHide();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _opening = false;
        _buffering = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= _videos.length) return;
    setState(() => _index = index);
    await _openCurrent();
  }

  void _showControls({bool keepVisible = false}) {
    if (!_controlsVisible && mounted) {
      setState(() => _controlsVisible = true);
    }
    _hideTimer?.cancel();
    if (!keepVisible && _playing) _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _hideTimer?.cancel();
    if (!_playing || _error != null) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  Future<void> _togglePlay() async {
    _showControls();
    await _player.playOrPause();
  }

  Future<void> _seekRelative(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final bounded = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration
            ? _duration
            : target);
    await _player.seek(bounded);
    _showControls();
  }

  Future<void> _toggleFullscreen() async {
    final state = _videoKey.currentState;
    if (state == null) return;
    if (_fullscreen) {
      await state.exitFullscreen();
    } else {
      await state.enterFullscreen();
    }
    if (mounted) setState(() => _fullscreen = !_fullscreen);
  }

  Future<void> _captureCurrentFrame() async {
    if (_captureBusy || _opening || _error != null) return;
    _showControls();
    _captureNoticeTimer?.cancel();
    setState(() {
      _capturingFrame = true;
      _captureFailed = false;
      _captureNotice = Intl.playerScreenshot_capturing.tr;
      _capturePath = null;
    });

    try {
      final bytes = await _player.screenshot(format: 'image/png');
      if (bytes == null || bytes.isEmpty) {
        throw StateError('The player returned an empty frame.');
      }

      final outputDirectory = await _captureOutputDirectory();

      final output = File(p.join(outputDirectory.path, _screenshotFileName()));
      await output.writeAsBytes(bytes, flush: true);
      _showCaptureNotice(
        Intl.playerScreenshot_saved.tr,
        path: output.path,
      );
    } catch (error) {
      _showCaptureNotice(
        '${Intl.playerScreenshot_failed.tr}: $error',
        failed: true,
      );
    } finally {
      if (mounted) setState(() => _capturingFrame = false);
    }
  }

  Future<void> _captureContactSheet() async {
    if (_captureBusy ||
        _opening ||
        _error != null ||
        _duration <= Duration.zero) {
      return;
    }

    const frameCount = 9;
    final generatedAt = DateTime.now();
    final originalPosition = _position;
    final wasPlaying = _playing;
    final frames = <ui.Image>[];
    final positions = <Duration>[];
    String? outputPath;
    Object? captureError;

    _showControls(keepVisible: true);
    _captureNoticeTimer?.cancel();
    setState(() {
      _generatingContactSheet = true;
      _captureFailed = false;
      _captureNotice = '${Intl.playerContactSheet_generating.tr} 0/$frameCount';
      _capturePath = null;
    });

    try {
      await _player.pause();
      for (var index = 0; index < frameCount; index++) {
        if (!mounted) return;
        final target = Duration(
          microseconds:
              _duration.inMicroseconds * (index + 1) ~/ (frameCount + 1),
        );
        await _player.seek(target);
        await _waitForFrameAt(target);

        final bytes = await _player.screenshot(format: 'image/png');
        if (bytes == null || bytes.isEmpty) {
          throw StateError('The player returned an empty frame.');
        }
        frames.add(await _decodeFrame(bytes));
        positions.add(target);

        if (mounted) {
          setState(() {
            _captureNotice =
                '${Intl.playerContactSheet_generating.tr} ${index + 1}/$frameCount';
          });
        }
      }

      final png = await _renderContactSheet(frames, positions, generatedAt);
      final outputDirectory = await _captureOutputDirectory();
      final output = File(
        p.join(outputDirectory.path, _contactSheetFileName(generatedAt)),
      );
      await output.writeAsBytes(png, flush: true);
      outputPath = output.path;
    } catch (error) {
      captureError = error;
    } finally {
      try {
        await _player.seek(originalPosition);
        if (wasPlaying) await _player.play();
      } catch (_) {
        // A saved contact sheet remains valid even if playback cannot restore.
      }
      for (final frame in frames) {
        frame.dispose();
      }
      if (mounted) setState(() => _generatingContactSheet = false);
    }

    if (!mounted) return;
    if (captureError != null || outputPath == null) {
      _showCaptureNotice(
        '${Intl.playerContactSheet_failed.tr}: $captureError',
        failed: true,
      );
    } else {
      _showCaptureNotice(
        Intl.playerContactSheet_saved.tr,
        path: outputPath,
      );
    }
  }

  Future<void> _waitForFrameAt(Duration target) async {
    bool isNear(Duration value) => (value - target).inMilliseconds.abs() <= 500;

    if (!isNear(_position)) {
      try {
        await _player.stream.position
            .firstWhere(isNear)
            .timeout(const Duration(milliseconds: 800));
      } on TimeoutException {
        // seek() completed; give the renderer a short chance to present it.
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  Future<ui.Image> _decodeFrame(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  Future<Uint8List> _renderContactSheet(
    List<ui.Image> frames,
    List<Duration> positions,
    DateTime generatedAt,
  ) async {
    if (frames.length != 9 || positions.length != frames.length) {
      throw StateError('A 3x3 contact sheet requires exactly 9 frames.');
    }

    const columns = 3;
    const rows = 3;
    const gridWidth = 1920.0;
    const infoWidth = 360.0;
    const infoGap = 18.0;
    const outerPadding = 36.0;
    const gap = 14.0;
    const headerHeight = 92.0;
    const labelHeight = 38.0;
    const sheetWidth = gridWidth + infoGap + infoWidth + outerPadding;
    final source = frames.first;
    const tileWidth =
        (gridWidth - outerPadding * 2 - gap * (columns - 1)) / columns;
    final tileHeight = tileWidth * source.height / source.width;
    final sheetHeight =
        outerPadding * 2 + headerHeight + tileHeight * rows + gap * (rows - 1);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, sheetWidth, sheetHeight),
      Paint()..color = const Color(0xFF101319),
    );

    final titlePainter = TextPainter(
      text: TextSpan(
        text: _displayTitle(_current.name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: gridWidth - outerPadding * 2 - 260);
    titlePainter.paint(canvas, const Offset(outerPadding, outerPadding));

    final summaryPainter = TextPainter(
      text: TextSpan(
        text: '3 × 3  ·  ${_formatDuration(_duration)}',
        style: const TextStyle(
          color: Color(0xB3FFFFFF),
          fontSize: 21,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    summaryPainter.paint(
      canvas,
      Offset(
        gridWidth - outerPadding - summaryPainter.width,
        outerPadding + 7,
      ),
    );

    for (var index = 0; index < frames.length; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      final left = outerPadding + column * (tileWidth + gap);
      final top = outerPadding + headerHeight + row * (tileHeight + gap);
      final tileRect = Rect.fromLTWH(left, top, tileWidth, tileHeight);
      final roundedRect = RRect.fromRectAndRadius(
        tileRect,
        const Radius.circular(12),
      );

      canvas.save();
      canvas.clipRRect(roundedRect);
      canvas.drawImageRect(
        frames[index],
        Rect.fromLTWH(
          0,
          0,
          frames[index].width.toDouble(),
          frames[index].height.toDouble(),
        ),
        tileRect,
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          left,
          top + tileHeight - labelHeight,
          tileWidth,
          labelHeight,
        ),
        Paint()..color = const Color(0xB8000000),
      );

      final labelPainter = TextPainter(
        text: TextSpan(
          text:
              '${(index + 1).toString().padLeft(2, '0')}  ·  ${_formatDuration(positions[index])}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(left + 13, top + tileHeight - labelHeight + 8),
      );
      canvas.restore();

      canvas.drawRRect(
        roundedRect,
        Paint()
          ..color = const Color(0x2EFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    final infoRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        gridWidth + infoGap,
        outerPadding,
        infoWidth,
        sheetHeight - outerPadding * 2,
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(
      infoRect,
      Paint()..color = const Color(0xFF181C23),
    );
    canvas.drawRRect(
      infoRect,
      Paint()
        ..color = const Color(0x29FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    const infoLeft = gridWidth + infoGap + 26;
    const infoContentWidth = infoWidth - 52;
    final infoTitle = TextPainter(
      text: const TextSpan(
        text: 'INFO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 25,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    infoTitle.paint(canvas, const Offset(infoLeft, outerPadding + 24));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(infoLeft, outerPadding + 62, 42, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF74A8FF),
    );

    final infoFields = <MapEntry<String, String>>[
      MapEntry('FILE', _current.name),
      MapEntry('DURATION', _formatDuration(_duration)),
      MapEntry('RESOLUTION', '${source.width} × ${source.height}'),
      MapEntry(
        'SIZE',
        _current.size == null
            ? '—'
            : (FileUtils.formatBytes(_current.size!) ?? '—'),
      ),
      const MapEntry('FRAMES', '9  ·  3 × 3'),
      MapEntry(
        'SAMPLE RANGE',
        '${_formatDuration(positions.first)} — ${_formatDuration(positions.last)}',
      ),
      MapEntry('SOURCE', _contactSheetSourceLabel()),
      MapEntry('GENERATED', _formatInfoDate(generatedAt)),
    ];
    var infoY = outerPadding + 96;
    for (final field in infoFields) {
      final label = TextPainter(
        text: TextSpan(
          text: field.key,
          style: const TextStyle(
            color: Color(0x8FFFFFFF),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: infoContentWidth);
      label.paint(canvas, Offset(infoLeft, infoY));
      infoY += label.height + 8;

      final value = TextPainter(
        text: TextSpan(
          text: field.value,
          style: TextStyle(
            color: Colors.white,
            fontSize: field.key == 'FILE' ? 16 : 19,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        maxLines: field.key == 'FILE' ? 3 : 2,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: infoContentWidth);
      value.paint(canvas, Offset(infoLeft, infoY));
      infoY += value.height + 19;

      canvas.drawLine(
        Offset(infoLeft, infoY),
        Offset(infoLeft + infoContentWidth, infoY),
        Paint()
          ..color = const Color(0x1FFFFFFF)
          ..strokeWidth = 1,
      );
      infoY += 18;
    }

    final brand = TextPainter(
      text: const TextSpan(
        text: 'LISTLINKER',
        style: TextStyle(
          color: Color(0x52FFFFFF),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    brand.paint(
      canvas,
      Offset(
        infoLeft,
        sheetHeight - outerPadding - brand.height - 24,
      ),
    );

    final picture = recorder.endRecording();
    final sheetImage = await picture.toImage(
      sheetWidth.ceil(),
      sheetHeight.ceil(),
    );
    picture.dispose();
    try {
      final data = await sheetImage.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Could not encode contact sheet.');
      return data.buffer.asUint8List();
    } finally {
      sheetImage.dispose();
    }
  }

  Future<Directory> _captureOutputDirectory() async {
    final downloads = await getDownloadsDirectory();
    final fallback = await getApplicationDocumentsDirectory();
    final outputDirectory = Directory(
      p.join((downloads ?? fallback).path, 'ListLinker Screenshots'),
    );
    await outputDirectory.create(recursive: true);
    try {
      return Directory(await outputDirectory.resolveSymbolicLinks());
    } on FileSystemException {
      return outputDirectory;
    }
  }

  void _showCaptureNotice(
    String message, {
    String? path,
    bool failed = false,
  }) {
    if (!mounted) return;
    _captureNoticeTimer?.cancel();
    setState(() {
      _captureFailed = failed;
      _captureNotice = message;
      _capturePath = path;
    });
    _captureNoticeTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _captureNotice = null;
        _capturePath = null;
      });
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final exportFrame = event.logicalKey == LogicalKeyboardKey.keyE &&
        (Platform.isMacOS
            ? HardwareKeyboard.instance.isMetaPressed
            : HardwareKeyboard.instance.isControlPressed);
    if (exportFrame) {
      _captureCurrentFrame();
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlay();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seekRelative(-10);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seekRelative(10);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _player.setVolume((_volume + 5).clamp(0, 100));
      _showControls();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _player.setVolume((_volume - 5).clamp(0, 100));
      _showControls();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_fullscreen) {
        _toggleFullscreen();
      } else {
        Get.back();
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0D),
      body: Focus(
        autofocus: true,
        focusNode: _focusNode,
        onKeyEvent: _onKeyEvent,
        child: MouseRegion(
          onEnter: (_) => _showControls(),
          onHover: (_) => _showControls(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_controlsVisible) {
                _hideTimer?.cancel();
                setState(() => _controlsVisible = false);
              } else {
                _showControls();
              }
            },
            onDoubleTap: _toggleFullscreen,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Video(
                  key: _videoKey,
                  controller: _videoController,
                  fit: BoxFit.contain,
                  fill: const Color(0xFF080A0D),
                  controls: NoVideoControls,
                ),
                if (_opening || (_buffering && _error == null))
                  const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                if (_error != null) _buildErrorState(),
                _buildTopBar(),
                _buildCenterControl(),
                _buildBottomControls(),
                _buildCaptureNotice(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Align(
      alignment: Alignment.topCenter,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            height: 92,
            padding: const EdgeInsets.fromLTRB(18, 14, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xD9000000), Color(0x00000000)],
              ),
            ),
            child: Row(
              children: [
                _roundIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Get.back(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayTitle(_current.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _current.localPath?.isNotEmpty == true
                            ? Intl.screenName_localFiles.tr
                            : (_current.provider ?? Intl.screenName_smb.tr),
                        style: const TextStyle(
                          color: Color(0xB3FFFFFF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterControl() {
    if (_error != null || _opening || _buffering) return const SizedBox();
    return Center(
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedScale(
          scale: _controlsVisible ? 1 : 0.92,
          duration: const Duration(milliseconds: 160),
          child: AnimatedOpacity(
            opacity: _controlsVisible ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: IconButton.filled(
              onPressed: _togglePlay,
              iconSize: 34,
              padding: const EdgeInsets.all(16),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xCC101419),
                foregroundColor: Colors.white,
              ),
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final max = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final position = _position.inMilliseconds.toDouble().clamp(0.0, max);
    final buffer = _buffer.inMilliseconds.toDouble().clamp(0.0, max);

    return Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 42, 22, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0xF2000000)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: const Color(0xFF83B7FF),
                    inactiveTrackColor: const Color(0x4DFFFFFF),
                    secondaryActiveTrackColor: const Color(0x80FFFFFF),
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: position,
                    secondaryTrackValue: buffer,
                    min: 0,
                    max: max,
                    onChanged: _duration == Duration.zero
                        ? null
                        : (value) {
                            setState(() => _position =
                                Duration(milliseconds: value.round()));
                            _showControls(keepVisible: true);
                          },
                    onChangeEnd: (value) {
                      _player.seek(Duration(milliseconds: value.round()));
                      _showControls();
                    },
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    IconButton(
                      tooltip: _playing ? '暂停 (Space)' : '播放 (Space)',
                      onPressed: _togglePlay,
                      icon: Icon(
                        _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    IconButton(
                      tooltip: '后退 10 秒',
                      onPressed: () => _seekRelative(-10),
                      icon: const Icon(Icons.replay_10_rounded),
                      color: Colors.white,
                    ),
                    IconButton(
                      tooltip: '前进 10 秒',
                      onPressed: () => _seekRelative(10),
                      icon: const Icon(Icons.forward_10_rounded),
                      color: Colors.white,
                    ),
                    if (_videos.length > 1) ...[
                      IconButton(
                        tooltip: '上一个',
                        onPressed:
                            _index > 0 ? () => _playAt(_index - 1) : null,
                        icon: const Icon(Icons.skip_previous_rounded),
                        color: Colors.white,
                      ),
                      IconButton(
                        tooltip: '下一个',
                        onPressed: _index < _videos.length - 1
                            ? () => _playAt(_index + 1)
                            : null,
                        icon: const Icon(Icons.skip_next_rounded),
                        color: Colors.white,
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDuration(_position)} / '
                      '${_formatDuration(_duration)}',
                      style: const TextStyle(
                        color: Color(0xD9FFFFFF),
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: _volume == 0 ? '取消静音' : '静音',
                      onPressed: () => _player.setVolume(_volume == 0 ? 70 : 0),
                      icon: Icon(
                        _volume == 0
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                      ),
                      color: Colors.white,
                    ),
                    SizedBox(
                      width: 92,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 4,
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: _volume.clamp(0, 100),
                          min: 0,
                          max: 100,
                          onChanged: _player.setVolume,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<double>(
                      tooltip: '播放速度',
                      initialValue: _rate,
                      onSelected: _player.setRate,
                      color: const Color(0xFF20252B),
                      itemBuilder: (_) => const <double>[
                        0.5,
                        0.75,
                        1,
                        1.25,
                        1.5,
                        2,
                      ]
                          .map(
                            (rate) => PopupMenuItem(
                              value: rate,
                              child: Text(
                                '${rate}x',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Text(
                          '${_rate}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip:
                          '${Intl.playerScreenshot_action.tr} ($_captureShortcut)',
                      onPressed: _captureBusy ? null : _captureCurrentFrame,
                      icon: _capturingFrame
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt_outlined),
                      color: Colors.white,
                    ),
                    IconButton(
                      tooltip: Intl.playerContactSheet_action.tr,
                      onPressed: _captureBusy ? null : _captureContactSheet,
                      icon: _generatingContactSheet
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.grid_view_rounded),
                      color: Colors.white,
                    ),
                    IconButton(
                      tooltip: _fullscreen ? '退出全屏' : '全屏',
                      onPressed: _toggleFullscreen,
                      icon: Icon(
                        _fullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                      ),
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureNotice() {
    return Positioned(
      top: 22,
      right: 22,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _captureNotice == null
            ? const SizedBox.shrink()
            : Container(
                key: ValueKey('$_captureNotice$_capturePath'),
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xEE181C22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_captureBusy)
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(
                        _captureFailed
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 20,
                        color: _captureFailed
                            ? const Color(0xFFFF9B9B)
                            : const Color(0xFF8BE0B1),
                      ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _captureNotice!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_capturePath != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              _capturePath!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xB3FFFFFF),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xE6181B20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white70, size: 34),
            const SizedBox(height: 12),
            Text(
              Intl.playerSkin_tips_playVideoFailed.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xB3FFFFFF), height: 1.35),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _openCurrent,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(Intl.loadingStatusWidget_retry.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: const Color(0x66000000),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon),
    );
  }

  String _displayTitle(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  String get _captureShortcut => Platform.isMacOS ? '⌘E' : 'Ctrl+E';

  String _captureTimestamp([DateTime? value]) {
    final now = value ?? DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  String _safeCaptureTitle() {
    final sanitized = _displayTitle(_current.name)
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    if (sanitized.isEmpty) return 'frame';
    return sanitized.length > 80 ? sanitized.substring(0, 80) : sanitized;
  }

  String _screenshotFileName() {
    final position = _formatDuration(_position).replaceAll(':', '-');
    return '${_safeCaptureTitle()}_${position}_${_captureTimestamp()}.png';
  }

  String _contactSheetFileName(DateTime generatedAt) {
    return '${_safeCaptureTitle()}_contact-sheet_3x3_${_captureTimestamp(generatedAt)}.png';
  }

  String _contactSheetSourceLabel() {
    final provider = _current.provider?.trim();
    if (provider?.isNotEmpty == true) return provider!;
    if (_current.localPath?.isNotEmpty == true) return 'Local';
    if (_current.playUrl?.isNotEmpty == true) return 'Network stream';
    return 'Remote';
  }

  String _formatInfoDate(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}:${twoDigits(value.second)}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  void dispose() {
    if (Platform.isMacOS) {
      unawaited(
        _videoCommandChannel.invokeMethod<void>(
          'setCaptureShortcutEnabled',
          false,
        ),
      );
      _videoCommandChannel.setMethodCallHandler(null);
    }
    _hideTimer?.cancel();
    _captureNoticeTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _focusNode.dispose();
    _player.dispose();
    if (_proxyStarted && Get.isRegistered<ProxyServer>()) {
      Get.find<ProxyServer>().stop();
    }
    super.dispose();
  }
}
