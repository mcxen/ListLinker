# Fix: Search results end abruptly beneath a page with no app bar

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/progressive-fade
- **Needs new dependency**: none

## Why

File search deliberately removes the app bar and places a scrolling result list directly below its search row. A progressive alpha mask gives the top edge a soft transition as results move beneath the fixed chrome, in both light and dark mode.

## Where

~~~dart
// lib/screen/file_search_screen.dart:50 — current page without app bar
return AlistScaffold(
  showAppbar: false,
  body: Column(
    children: [
~~~

~~~dart
// lib/screen/file_search_screen.dart:107 — current scrolling child
Expanded(child: _buildList(context, controller)),
~~~

## The fix

Create the article's reusable alpha-only mask:

~~~dart
// lib/widget/progressive_fade.dart — target
import 'package:flutter/material.dart';

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
              stops: [0.0, end * 0.25, end * 0.5, end * 0.75, end],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: child,
        );
      },
    );
  }
}
~~~

Wrap only the result viewport so the fixed search field and Cancel action remain fully opaque:

~~~dart
// lib/screen/file_search_screen.dart — target
Expanded(
  child: ProgressiveFade(
    height: 72,
    child: _buildList(context, controller),
  ),
),
~~~

## Steps

1. Create lib/widget/progressive_fade.dart exactly as shown.
2. Import it in file_search_screen.dart.
3. Replace the one-line Expanded result child with the target wrapper and height 72.
4. Keep the search field, Cancel action, list padding, safe area, keyboard behavior, and result builder unchanged.

## Check it

- `dart analyze` exits clean.
- `rg -n "class ProgressiveFade|ShaderMask|BlendMode.dstIn|end \* 0.25|end \* 0.75" lib/widget/progressive_fade.dart` returns the progressive mask.
- `rg -n "ProgressiveFade|height: 72|_buildList" lib/screen/file_search_screen.dart` returns the single result wrapper.
- `rg -n "showAppbar: false" lib/screen/file_search_screen.dart` still returns the page configuration.

## Don't touch

- Do not fade the fixed search field or Cancel action.
- Do not change safe-area handling, search debounce, result ordering, or keyboard dismissal.
- Do not apply this mask globally to pages with app bars.
- No new dependencies or unrelated layout changes.

## STOP if

- The result list no longer scrolls beneath fixed page chrome.
- The code at any location in "Where" does not match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that file-search results now fade softly at the top while the search controls stay crisp. Search for enough files to scroll and watch rows move into the top edge.
