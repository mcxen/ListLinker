import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sp_util/sp_util.dart';

class AppSlidable extends StatefulWidget {
  const AppSlidable({
    super.key,
    required this.child,
    this.startActionPane,
    this.endActionPane,
    this.hintPreferenceKey,
  });

  final Widget child;
  final ActionPane? startActionPane;
  final ActionPane? endActionPane;
  final String? hintPreferenceKey;

  @override
  State<AppSlidable> createState() => _AppSlidableState();
}

class _AppSlidableState extends State<AppSlidable>
    with SingleTickerProviderStateMixin {
  late final SlidableController _controller;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = SlidableController(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleHint();
  }

  @override
  void didUpdateWidget(covariant AppSlidable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleHint();
  }

  bool get _canShowHint =>
      mounted &&
      TickerMode.of(context) &&
      !MediaQuery.disableAnimationsOf(context);

  void _scheduleHint() {
    final preferenceKey = widget.hintPreferenceKey;
    if (_scheduled ||
        !_canShowHint ||
        preferenceKey == null ||
        SpUtil.getBool(preferenceKey) == true) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _runHint(preferenceKey),
    );
  }

  Future<void> _runHint(String preferenceKey) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (!_canShowHint || SpUtil.getBool(preferenceKey) == true) {
      _scheduled = false;
      return;
    }
    if (widget.endActionPane != null) {
      await _controller.openEndActionPane(
        duration: const Duration(milliseconds: 400),
      );
    } else if (widget.startActionPane != null) {
      await _controller.openStartActionPane(
        duration: const Duration(milliseconds: 400),
      );
    } else {
      return;
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (!_canShowHint) {
      await _controller.close(duration: Duration.zero);
      _scheduled = false;
      return;
    }
    await _controller.close(duration: const Duration(milliseconds: 300));
    await SpUtil.putBool(preferenceKey, true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Slidable(
      controller: _controller,
      startActionPane: widget.startActionPane,
      endActionPane: widget.endActionPane,
      child: widget.child,
    );
  }
}
