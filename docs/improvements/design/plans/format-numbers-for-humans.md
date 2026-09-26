# Fix: Counts and file sizes ignore the user's number format

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/format-numbers-for-humans
- **Needs new dependency**: none; intl is already installed

## Why

Visible counts and byte values are assembled from raw integers or fixed decimal strings. Large values therefore lack the grouping and decimal separators expected in the user's region.

## Where

~~~dart
// lib/util/file_utils.dart:300 — current
return "\${(size / pow(1024, i)).toStringAsFixed(2)}\${suffixes[i]}";
~~~

~~~dart
// lib/screen/cache_manager.dart:147 — current
String format(double value) {
  if (value.truncate() == value) {
    return value.toInt().toString();
  } else {
    return value.toStringAsFixed(1);
  }
}
~~~

~~~dart
// lib/screen/audio_player_screen.dart:193 — current
"\${Intl.audioPlayListDialog_title.tr}(\${controller._audios.length})",
~~~

~~~dart
// lib/screen/smb/smb_scan_screen.dart:117 — current
'$_scanned / $_total',
~~~

~~~dart
// lib/screen/local_storage_browser_screen.dart:956 — current
'\${_visibleEntries.length} \${Intl.fileManager_items.tr}',
~~~

~~~dart
// lib/screen/smb/smb_browser_screen.dart:156 — current
'\${_visibleFiles.length} \${Intl.fileManager_items.tr} · SMB',
~~~

~~~dart
// lib/screen/file_list/file_copy_move_dialog.dart:169 — current
'\${isCopy ? Intl.fileCopyMoveDialog_copy.tr : Intl.fileCopyMoveDialog_move.tr}(\${controller.names.length})'),
~~~

## The fix

Set intl's default locale from the same platform locale used by GetMaterialApp, then add the article's reusable number extension:

~~~dart
// lib/main.dart — target before runApp
Intl.defaultLocale = PlatformDispatcher.instance.locale.toLanguageTag();
runApp(const MyApp());
~~~

~~~dart
// lib/util/number_utils.dart — target
import 'package:intl/intl.dart';

extension HumanizedNumber on num {
  String humanizedCount({int? decimalDigits}) {
    return NumberFormat.decimalPatternDigits(
      decimalDigits: decimalDigits,
    ).format(this);
  }

  String humanizedCompact() {
    return NumberFormat.compact().format(this);
  }
}
~~~

Use humanizedCount for all quantities in "Where":

~~~dart
// target examples
final count = controller._audios.length.humanizedCount();
final scanned = _scanned.humanizedCount();
final total = _total.humanizedCount();
final value = (size / pow(1024, i)).humanizedCount(decimalDigits: 2);
~~~

Keep IDs, ports, versions, timestamps used in file names, indexes, and route parameters raw because users read those as "which one", not "how much".

## Steps

1. Import package:intl/intl.dart in lib/main.dart and set Intl.defaultLocale immediately before runApp.
2. Create lib/util/number_utils.dart with HumanizedNumber exactly as shown.
3. In lib/util/file_utils.dart, import number_utils.dart and replace toStringAsFixed(2) in formatBytes with humanizedCount(decimalDigits: 2).
4. In lib/screen/cache_manager.dart, import number_utils.dart and replace the inner raw-number formatter with humanizedCount using zero decimal digits for integers and one otherwise.
5. In audio_player_screen.dart, format the playlist length before interpolating it into the title.
6. In smb_scan_screen.dart, format both changing scan counters.
7. In local_storage_browser_screen.dart and smb_browser_screen.dart, format the visible item counts.
8. In file_copy_move_dialog.dart, format controller.names.length in the action label.

## Check it

- dart analyze exits clean.
- rg -n "Intl.defaultLocale" lib/main.dart returns exactly one assignment.
- rg -n "extension HumanizedNumber|decimalPatternDigits|humanizedCompact" lib/util/number_utils.dart returns all helper members.
- rg -n "toStringAsFixed|value.toInt\\(\\).toString" lib/util/file_utils.dart lib/screen/cache_manager.dart returns no display-formatting matches.
- rg -n "humanizedCount" in each edited screen returns the expected display use.

## Don't touch

- Do not format server ports, route indexes, IDs, semantic versions, timestamps embedded in capture file names, or internal network values.
- Do not change byte units or the two-decimal file-size precision.
- Do not add a second number-formatting package.
- No new dependencies.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- The app gains a runtime language picker that can change locale without restarting; in that case the default-locale assignment needs a separate design decision.
- The code at any location in "Where" doesn't match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that user-facing counts and file sizes now use regional separators while IDs and technical values remain unchanged. Open SMB scanning or a large local folder under two device locales to compare.
