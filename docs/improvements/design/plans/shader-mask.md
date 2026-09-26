# Fix: The mobile breadcrumb row does not look horizontally scrollable

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/shader-mask
- **Needs new dependency**: none

## Why

Long local-folder paths fit inside a compact toolbar and can look like static, clipped text. A small alpha fade at both horizontal edges signals that the breadcrumb trail can be dragged without adding permanent chrome.

## Where

~~~dart
// lib/screen/local_storage_browser_screen.dart:444 — current
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
~~~

## The fix

Add the article's reusable alpha-mask widget. It must use white only as an alpha source so it behaves identically in light and dark themes:

~~~dart
// lib/widget/edge_fade.dart — target
import 'package:flutter/material.dart';

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
            fadeStart
                ? const Color(0x00FFFFFF)
                : const Color(0xFFFFFFFF),
            const Color(0xFFFFFFFF),
            const Color(0xFFFFFFFF),
            fadeEnd
                ? const Color(0x00FFFFFF)
                : const Color(0xFFFFFFFF),
          ],
          stops: const [0.0, 0.12, 0.88, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
~~~

Wrap only the breadcrumb scroll view:

~~~dart
// lib/screen/local_storage_browser_screen.dart — target
return EdgeFade(
  axis: Axis.horizontal,
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    reverse: true,
    child: Row(
      children: [
        // existing breadcrumb children unchanged
      ],
    ),
  ),
);
~~~

## Steps

1. Create lib/widget/edge_fade.dart with the complete EdgeFade implementation above.
2. Import edge_fade.dart in lib/screen/local_storage_browser_screen.dart.
3. Wrap the existing breadcrumb SingleChildScrollView in EdgeFade(axis: Axis.horizontal); keep reverse, item order, selection, tap handlers, and chevrons unchanged.
4. Do not wrap the gallery page view; it is a paged image viewer, not a horizontal list.

## Check it

- dart analyze exits clean.
- rg -n "class EdgeFade|BlendMode.dstIn|0.12, 0.88" lib/widget/edge_fade.dart returns all three targets.
- rg -n "EdgeFade|Axis.horizontal" lib/screen/local_storage_browser_screen.dart shows the wrapper and existing horizontal scroll.

## Don't touch

- Do not change breadcrumb order, reverse scrolling, selected state, or navigation callbacks.
- Do not apply the mask to ExtendedImageGesturePageView in the gallery.
- Do not add scroll indicators or dependencies.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- The breadcrumb code no longer matches the quoted excerpt.
- A parent already applies a ShaderMask to this toolbar.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that long local-folder breadcrumbs now fade at the edges to advertise horizontal scrolling. Open a deeply nested local folder on a narrow phone to see it.
