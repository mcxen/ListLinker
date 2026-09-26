# Fix: Contact-sheet dates are hand-built and ignore locale

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/format-date-times
- **Needs new dependency**: none; intl is already installed

## Why

Most file dates already pass through intl DateFormat, but the desktop contact-sheet timestamp is assembled manually as a fixed year-month-day string. It should use the user's locale and the same shared formatting boundary as other user-visible dates.

## Where

~~~dart
// lib/screen/desktop_video_player_screen.dart:592 — current user-visible value
MapEntry('GENERATED', _formatInfoDate(generatedAt)),
~~~

~~~dart
// lib/screen/desktop_video_player_screen.dart:1298 — current formatter
String _formatInfoDate(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}:${twoDigits(value.second)}';
}
~~~

~~~dart
// lib/screen/local_storage_browser_screen.dart:1840 — correct existing DateFormat boundary
String _formatDate(DateTime date, {bool includeYear = false}) {
  final pattern = includeYear || date.year != DateTime.now().year
      ? 'yyyy/MM/dd HH:mm'
      : 'MM/dd HH:mm';
  return date_format.DateFormat(pattern).format(date.toLocal());
}
~~~

## The fix

Add a shared nullable extension using the article's intl pattern:

~~~dart
// lib/util/date_time_utils.dart — target
import 'package:intl/intl.dart';

extension DateTimeDisplayX on DateTime? {
  String formattedDateTime(String localeName) {
    if (this == null) return 'N/A';
    return DateFormat('d MMMM yyyy, HH:mm', localeName).format(this!.toLocal());
  }
}
~~~

Initialize locale symbols before the app starts:

~~~dart
// lib/main.dart — target additions
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  MediaKit.ensureInitialized();
  // existing startup continues
}
~~~

Use the platform locale for the generated metadata and remove the private hand-built formatter:

~~~dart
// lib/screen/desktop_video_player_screen.dart — target
MapEntry(
  'GENERATED',
  generatedAt.formattedDateTime(
    ui.PlatformDispatcher.instance.locale.toString(),
  ),
),
~~~

The separate _captureTimestamp helper is a filename format, not user-facing display text, and must remain fixed and unchanged.

## Steps

1. Create lib/util/date_time_utils.dart with DateTimeDisplayX exactly as shown.
2. Import intl/date_symbol_data_local.dart in main.dart and await initializeDateFormatting immediately after WidgetsFlutterBinding.ensureInitialized.
3. Import date_time_utils.dart in desktop_video_player_screen.dart.
4. Replace the GENERATED value with formattedDateTime using ui.PlatformDispatcher's current locale.
5. Delete only _formatInfoDate; keep _captureTimestamp because filenames require a stable machine format.
6. Keep the existing local-storage DateFormat code unchanged.

## Check it

- `dart analyze` exits clean.
- `rg -n "DateFormat\('d MMMM yyyy, HH:mm'|formattedDateTime" lib/util/date_time_utils.dart lib/screen/desktop_video_player_screen.dart` returns the shared formatter and its use.
- `rg -n "initializeDateFormatting" lib/main.dart` returns the startup initialization.
- `rg -n "_formatInfoDate|value.year.*twoDigits" lib/screen/desktop_video_player_screen.dart` returns no matches.
- `rg -n "_captureTimestamp" lib/screen/desktop_video_player_screen.dart` still returns the filename helper and its callers.

## Don't touch

- Do not localize filenames, backend timestamps, database values, or request formats.
- Do not change the contact-sheet field labels or rendering layout.
- Do not replace intl or add another date package.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- The GENERATED field is no longer visible in the exported contact sheet.
- initializeDateFormatting is already performed through another startup path.
- The code at any location in "Where" does not match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that exported contact sheets now show their generated date in the user's locale. Export one contact sheet under English and Chinese locales and compare the GENERATED field.
