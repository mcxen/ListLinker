import 'package:flutter/material.dart';

/// Softens the top edge of scrolling content below fixed page chrome.
class ProgressiveFade extends StatelessWidget {
  const ProgressiveFade({
    super.key,
    required this.child,
    this.height = 72,
  });

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final end = (height / constraints.maxHeight).clamp(0.0, 1.0);
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Color(0x00FFFFFF),
                Color(0x26FFFFFF),
                Color(0x66FFFFFF),
                Color(0xB3FFFFFF),
                Color(0xFFFFFFFF),
              ],
              stops: [0, end * 0.25, end * 0.5, end * 0.75, end],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: child,
        );
      },
    );
  }
}
