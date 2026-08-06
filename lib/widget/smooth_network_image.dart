import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

/// Network image with a calm grey placeholder and subtle error state.
class SmoothNetworkImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).colorScheme.surfaceVariant;
    final errorIconColor = Theme.of(context).colorScheme.outline;

    Widget image = ExtendedImage.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return Container(
              width: width,
              height: height,
              color: placeholderColor,
            );
          case LoadState.completed:
            return null;
          case LoadState.failed:
            return fallback ??
                Container(
                  width: width,
                  height: height,
                  color: placeholderColor,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: ((width ?? 35) * 0.45).clamp(14.0, 28.0),
                    color: errorIconColor,
                  ),
                );
        }
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
