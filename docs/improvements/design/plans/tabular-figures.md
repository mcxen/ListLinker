# Fix: Changing timers, progress values, and counts shift horizontally

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/tabular-figures
- **Needs new dependency**: none

## Why

Most playback timers already use tabular figures, but the seek overlay, SMB scan counters, live cache sizes, and item totals do not. As narrow and wide digits replace each other, adjacent text can visibly move.

## Where

~~~dart
// lib/widget/player_skin.dart:1210 — current
Text("$currentPosStr / $durationStr",
    style: Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(color: Colors.white)),
~~~

~~~dart
// lib/screen/smb/smb_scan_screen.dart:116 — current
Text(
  '$_scanned / $_total',
  textAlign: TextAlign.center,
  style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppUi.muted(context),
      ),
),
~~~

~~~dart
// lib/screen/cache_manager.dart:26 — current
subtitle: Obx(() => Text(controller.imageCacheSizeStr.value)),
~~~

~~~dart
// lib/screen/audio_player_screen.dart:192 — current
child: Text(
  "\${Intl.audioPlayListDialog_title.tr}(\${controller._audios.length})",
  style: Theme.of(context).textTheme.titleMedium,
),
~~~

~~~dart
// lib/screen/local_storage_browser_screen.dart:955 — current
Text(
  '\${_visibleEntries.length} \${Intl.fileManager_items.tr}',
  style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
),
~~~

~~~dart
// lib/screen/smb/smb_browser_screen.dart:155 — current
child: Text(
  '\${_visibleFiles.length} \${Intl.fileManager_items.tr} · SMB',
  style: Theme.of(context).textTheme.bodySmall,
),
~~~

## The fix

Add FontFeature.tabularFigures only to the styles of changing or aligned numeric text:

~~~dart
// target style pattern
style: existingStyle?.copyWith(
  fontFeatures: const [FontFeature.tabularFigures()],
),
~~~

When the current style already has copyWith arguments, add fontFeatures to the same call:

~~~dart
style: Theme.of(context).textTheme.labelMedium?.copyWith(
  color: AppUi.muted(context),
  fontFeatures: const [FontFeature.tabularFigures()],
),
~~~

For cache subtitles with no existing style:

~~~dart
const tabularStyle = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
);
subtitle: Obx(
  () => Text(controller.imageCacheSizeStr.value, style: tabularStyle),
),
~~~

Match the already-correct playback styles in audio_player_screen.dart and the main player timer, both of which use FontFeature.tabularFigures().

## Steps

1. In player_skin.dart, add tabularFigures to the horizontal-drag current-position/duration overlay; preserve titleLarge and white.
2. In smb_scan_screen.dart, import dart:ui show FontFeature and add tabularFigures to the scan progress text.
3. In cache_manager.dart, import dart:ui show FontFeature, define one const tabular TextStyle in build, and reuse it for image, audio, and other cache-size subtitles.
4. In audio_player_screen.dart, add tabularFigures to the playlist title that contains a changing item count.
5. In local_storage_browser_screen.dart and smb_browser_screen.dart, add tabularFigures to visible-item count/status labels.
6. Do not add the feature to ordinary sentences containing a one-off number.

## Check it

- dart analyze exits clean.
- rg -n "currentPosStr /.*durationStr" lib/widget/player_skin.dart still finds the seek overlay, and the next style block contains tabularFigures.
- rg -n "tabularFigures" lib/screen/smb/smb_scan_screen.dart lib/screen/cache_manager.dart lib/screen/audio_player_screen.dart lib/screen/local_storage_browser_screen.dart lib/screen/smb/smb_browser_screen.dart returns the expected styles.
- Existing rg matches for tabularFigures in the main audio and video timers remain present.

## Don't touch

- Do not apply tabular figures globally or to normal prose.
- Do not change timer, count, cache-size, or locale formatting logic.
- Do not alter typography size, weight, color, or alignment.
- No new dependencies.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- A listed text widget no longer displays a changing or aligned number.
- The code at any location in "Where" doesn't match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that remaining live counters and timers now keep a stable width. Watch an SMB scan, cache calculation, and a video seek gesture to see that surrounding text no longer jumps.
