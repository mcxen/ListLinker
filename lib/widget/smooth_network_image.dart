import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

/// Network image with a calm grey placeholder and subtle error state.
class SmoothNetworkImage extends StatefulWidget {
  const SmoothNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallback;

  @override
  State<SmoothNetworkImage> createState() => _SmoothNetworkImageState();
}

class _SmoothNetworkImageState extends State<SmoothNetworkImage>
    with SingleTickerProviderStateMixin {
  static const _fadeDuration = Duration(milliseconds: 260);

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: _fadeDuration,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _fadeController,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).colorScheme.surfaceVariant;
    final errorIconColor = Theme.of(context).colorScheme.outline;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    Widget image = ExtendedImage.network(
      widget.url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cache: true,
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            _fadeController.reset();
            return Container(
              width: widget.width,
              height: widget.height,
              color: placeholderColor,
            );
          case LoadState.completed:
            if (state.wasSynchronouslyLoaded || disableAnimations) {
              return state.completedWidget;
            }
            _fadeController.forward();
            return FadeTransition(
              opacity: _opacity,
              child: state.completedWidget,
            );
          case LoadState.failed:
            final error = widget.fallback ??
                Container(
                  width: widget.width,
                  height: widget.height,
                  color: placeholderColor,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: ((widget.width ?? 35) * 0.45).clamp(14.0, 28.0),
                    color: errorIconColor,
                  ),
                );
            if (disableAnimations) {
              return error;
            }
            _fadeController.forward();
            return FadeTransition(opacity: _opacity, child: error);
        }
      },
    );

    if (widget.borderRadius != null) {
      image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
    }
    return image;
  }
}
