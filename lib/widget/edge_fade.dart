import 'package:flutter/material.dart';

/// Uses an alpha-only gradient to hint that a scrollable continues.
class EdgeFade extends StatelessWidget {
  const EdgeFade({
    super.key,
    required this.child,
    this.axis = Axis.vertical,
    this.fadeStart = true,
    this.fadeEnd = true,
  });

  final Widget child;
  final Axis axis;
  final bool fadeStart;
  final bool fadeEnd;

  @override
  Widget build(BuildContext context) {
    final isVertical = axis == Axis.vertical;
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: isVertical ? Alignment.topCenter : Alignment.centerLeft,
          end: isVertical ? Alignment.bottomCenter : Alignment.centerRight,
          colors: [
            fadeStart ? const Color(0x00FFFFFF) : const Color(0xFFFFFFFF),
            const Color(0xFFFFFFFF),
            const Color(0xFFFFFFFF),
            fadeEnd ? const Color(0x00FFFFFF) : const Color(0xFFFFFFFF),
          ],
          stops: const [0, 0.12, 0.88, 1],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
