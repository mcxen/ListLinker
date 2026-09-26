# Fix: Full-screen gallery images pop in or fail without a calm state

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Locate quoted code by content and preserve concurrent changes.

- **Link**: https://flutterpro.design/details/md/smooth-image-loading
- **Needs new dependency**: none; reuse the installed `extended_image: ^8.1.1`

## Why

Shared thumbnails now have a quiet placeholder, a subtle failure state, caching, reduced-motion handling, and a 260ms fade. The full-screen gallery still uses raw ExtendedImage.network branches with no loading, failure, or fade treatment, so slow or broken images remain abrupt.

## Where

~~~dart
// lib/widget/smooth_network_image.dart:52 — correct current exemplar; do not edit
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
~~~

~~~dart
// lib/screen/gallery_screen.dart:358 — current remote branch
return ExtendedImage.network(
  url,
  fit: BoxFit.contain,
  mode: ExtendedImageMode.gesture,
  initGestureConfigHandler: (state) {
    return gestureConfig;
  },
~~~

~~~dart
// lib/screen/gallery_screen.dart:376 — current local-file URI branch
return ExtendedImage.network(
  Uri.file(localPath!).toString(),
  fit: BoxFit.contain,
  mode: ExtendedImageMode.gesture,
  initGestureConfigHandler: (state) {
    return gestureConfig;
  },
~~~

## The fix

Keep the gallery on ExtendedImage because completedWidget preserves its gesture implementation. Add one context-aware callback with the same 260ms duration and reduced-motion behavior as SmoothNetworkImage:

~~~dart
// lib/screen/gallery_screen.dart — target inside _ImageContainer
Widget? _galleryLoadState(
  BuildContext context,
  ExtendedImageState state,
) {
  final scheme = Theme.of(context).colorScheme;
  final disableAnimations = MediaQuery.disableAnimationsOf(context);
  switch (state.extendedImageLoadState) {
    case LoadState.loading:
      return ColoredBox(color: scheme.surfaceVariant);
    case LoadState.failed:
      return ColoredBox(
        color: scheme.surfaceVariant,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: scheme.outline,
          ),
        ),
      );
    case LoadState.completed:
      if (state.wasSynchronouslyLoaded || disableAnimations) {
        return state.completedWidget;
      }
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, opacity, child) {
          return Opacity(opacity: opacity, child: child);
        },
        child: state.completedWidget,
      );
  }
}
~~~

Pass the callback to both branches and enable the same cache behavior:

~~~dart
cache: true,
loadStateChanged: (state) => _galleryLoadState(context, state),
~~~

Do not alter GestureConfig, ExtendedImageMode.gesture, PageView behavior, or double-tap callbacks.

## Steps

1. Do not edit lib/widget/smooth_network_image.dart; its concurrent stateful fade implementation already handles this rule.
2. Add _galleryLoadState inside _ImageContainer in gallery_screen.dart exactly as shown.
3. Add cache: true and the context-aware loadStateChanged closure to the remote URL branch.
4. Add the same two fields to the local-file URI branch so gallery behavior does not change when its source switches.
5. Preserve every gesture configuration and double-tap statement byte-for-byte.

## Check it

- `dart analyze` exits clean.
- `rg -n "_galleryLoadState|loadStateChanged:.*_galleryLoadState|cache: true|Duration\(milliseconds: 260\)|state.wasSynchronouslyLoaded" lib/screen/gallery_screen.dart` returns one helper and both call sites.
- `rg -n "ExtendedImageMode.gesture|onDoubleTap|GestureConfig" lib/screen/gallery_screen.dart` still returns the existing gesture paths.
- `git diff -- lib/widget/smooth_network_image.dart` contains no changes from this plan's implementation session.

## Don't touch

- Do not modify or revert the current stateful SmoothNetworkImage implementation.
- Do not replace ExtendedImageGesturePageView or ExtendedImageMode.gesture.
- Do not remove pinch zoom, double-tap zoom, local-file selection, caching, or fallbacks.
- Do not add shimmer, spinners, technical error text, or a new package.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- lib/widget/smooth_network_image.dart no longer matches the correct exemplar above.
- ExtendedImageState no longer exposes completedWidget or wasSynchronouslyLoaded.
- The code at either gallery location no longer matches the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that the full-screen gallery now matches the already-improved thumbnail loading behavior without losing zoom. Open a remote image with throttled networking and confirm the placeholder, fade, and subtle broken-image state.
