# Fix: Empty space inside custom touch targets ignores taps

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/gesture-detector-hit-area
- **Needs new dependency**: none

## Why

Several custom player and selector controls use GestureDetector around padding, rows, or otherwise unpainted space. The visible tile or full video region looks tappable, but taps between its painted children can miss.

## Where

~~~dart
// lib/widget/player_skin.dart:652 — current
Widget widget = GestureDetector(
  onTap: _cancelAndRestartTimer,
  onDoubleTap: _onDoubleTap(),
  onVerticalDragDown: _onVerticalDragDown(),
~~~

~~~dart
// lib/widget/player_skin.dart:906 — current
child: GestureDetector(
  onTap: () {
    _cancelAndRestartTimer();
  },
  child: _buildCenter(),
),
~~~

~~~dart
// lib/widget/player_skin.dart:1370 — current
Widget widget = GestureDetector(
  onTap: () {
    if (index != i) {
      callback(i);
    }
  },
  child: Padding(
~~~

~~~dart
// lib/widget/player_selector_dialog.dart:30 — current
return GestureDetector(
  onTap: () {
    onPlayerClick(info);
  },
  child: _buildPlayerWidget(
~~~

## The fix

Add the article's one-line hit-test behavior immediately after each listed GestureDetector opening:

~~~dart
behavior: HitTestBehavior.opaque,
~~~

Use opaque, not translucent: these controls own their visual box and widgets behind them must not receive the same gesture.

The following existing detectors are already correct and must remain unchanged: the login dismiss layer uses translucent intentionally; file search, local-storage rows, password labels, and the desktop player already use opaque; the custom slider paints a transparent Container across its whole bounds.

## Steps

1. Add behavior: HitTestBehavior.opaque to the outer AlistPlayerSkin gesture surface.
2. Add it to the center player tap layer.
3. Add it to every audio-track selection-row GestureDetector.
4. Add it to each PlayerSelectorDialog grid-tile GestureDetector.
5. Preserve every tap, double-tap, drag, long-press, callback, child, and layout property.

## Check it

- dart analyze exits clean.
- rg -n "GestureDetector\\(|behavior: HitTestBehavior.opaque" lib/widget/player_skin.dart shows opaque immediately after all three affected detectors.
- rg -n -A3 "return GestureDetector" lib/widget/player_selector_dialog.dart includes behavior: HitTestBehavior.opaque.
- Existing HitTestBehavior.translucent in login_screen.dart remains unchanged.

## Don't touch

- Do not change opaque to translucent on these controls.
- Do not modify gesture callbacks, recognizer competition, drag thresholds, or player behavior.
- Do not add behavior to a detector whose child already paints its entire hit box, such as the custom slider.
- No new dependencies.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- A listed detector is no longer responsible for the complete visible box.
- Adding opaque would intercept a gesture intentionally handled by a widget behind it.
- The code at any location in "Where" doesn't match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that the full visible player and selector areas now accept taps, including padding and gaps. Tap between the icon and label in the external-player picker and across empty player space to verify.
