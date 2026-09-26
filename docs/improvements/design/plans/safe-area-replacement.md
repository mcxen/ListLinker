# Fix: Bottom list items collide with the system navigation bar

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/safe-area-replacement
- **Needs new dependency**: none

## Why

Several mobile scrollables still end with fixed or zero bottom padding. On gesture-navigation and three-button-navigation devices, the last row can sit against or underneath the system bar instead of retaining usable breathing room.

## Where

~~~dart
// lib/util/widget_utils.dart:9 — current
static double listBottomInset(BuildContext context) {
  return MediaQuery.viewPaddingOf(context).bottom;
}

static EdgeInsets listViewPadding(BuildContext context,
    {double extraBottom = 0}) {
  return EdgeInsets.only(bottom: listBottomInset(context) + extraBottom);
}
~~~

~~~dart
// lib/screen/cache_manager.dart:21 — current
body: SingleChildScrollView(
  child: Column(
~~~

~~~dart
// lib/screen/donate_screen.dart:98 — current
return ListView.builder(
  itemBuilder: (context, index) {
~~~

~~~dart
// lib/screen/login_screen.dart:52 — current
child: SingleChildScrollView(
  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
  child: LoginScreenContainer(),
),
~~~

~~~dart
// lib/screen/audio_player_screen.dart:212 — current
return ListView.separated(
  controller: scrollController,
  itemBuilder: (context, index) {
~~~

~~~dart
// lib/screen/file_list/file_copy_move_dialog.dart:185 — current
child: ListView.separated(
  itemBuilder: (context, index) {
~~~

~~~dart
// lib/widget/app_ui.dart:170 — current
child: SingleChildScrollView(
  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
  child: content,
),
~~~

## The fix

Keep AlistScaffold's existing SafeArea(bottom: false) behavior. Make the shared inset return the larger of the device bar and a 16 logical-pixel minimum, then use that value as scroll content padding:

~~~dart
// lib/util/widget_utils.dart — target
static double listBottomInset(
  BuildContext context, {
  double minimum = 16,
}) {
  final viewPadding = MediaQuery.viewPaddingOf(context).bottom;
  return viewPadding > minimum ? viewPadding : minimum;
}

static EdgeInsets listViewPadding(
  BuildContext context, {
  double extraBottom = 0,
}) {
  return EdgeInsets.only(
    bottom: listBottomInset(context) + extraBottom,
  );
}
~~~

For every scrollable listed in "Where", add dynamic content padding:

~~~dart
// cache manager, donate list, audio playlist, copy/move list — target
padding: WidgetUtils.listViewPadding(context),
~~~

~~~dart
// login scroll view — target
padding: WidgetUtils.listViewPadding(context),
keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
~~~

AppEmptyState already uses 32 pixels vertically, so preserve 32 as its minimum while allowing a taller device bar:

~~~dart
// lib/widget/app_ui.dart — target
padding: EdgeInsets.fromLTRB(
  28,
  32,
  28,
  WidgetUtils.listBottomInset(context, minimum: 32),
),
~~~

Match existing correct list usage in lib/screen/favorite_screen.dart, where list padding comes from WidgetUtils.listViewPadding(context).

## Steps

1. In lib/util/widget_utils.dart, add the minimum parameter and max calculation shown above; keep listViewPadding as the only shared list-padding constructor.
2. In lib/screen/cache_manager.dart, import widget_utils.dart and add WidgetUtils.listViewPadding(context) to SingleChildScrollView.
3. In lib/screen/donate_screen.dart, import widget_utils.dart and add WidgetUtils.listViewPadding(context) to ListView.builder.
4. In lib/screen/login_screen.dart, add WidgetUtils.listViewPadding(context) to the existing SingleChildScrollView without changing keyboard behavior or form spacing.
5. In lib/screen/audio_player_screen.dart, import widget_utils.dart and add WidgetUtils.listViewPadding(context) to the playlist ListView.separated.
6. In lib/screen/file_list/file_copy_move_dialog.dart, import widget_utils.dart and add WidgetUtils.listViewPadding(context) to the folder ListView.separated.
7. In lib/widget/app_ui.dart, replace AppEmptyState's const symmetric padding with the dynamic EdgeInsets.fromLTRB target above.
8. Leave manual expressions that already add both 16 and MediaQuery.viewPaddingOf(context).bottom unchanged; they already satisfy the invariant.

## Check it

- dart analyze exits clean.
- rg -n "minimum = 16|viewPadding > minimum" lib/util/widget_utils.dart returns both target lines.
- rg -n "WidgetUtils.listViewPadding" against each edited screen returns one new use in each file.
- rg -n "minimum: 32" lib/widget/app_ui.dart returns exactly one line.

## Don't touch

- Do not wrap these scrollables in SafeArea; that shrinks the viewport and clips content while it scrolls.
- Do not change AlistScaffold's SafeArea(bottom: false).
- Do not change desktop layout breakpoints or bottom-navigation height.
- No new dependencies.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- The code at any location in "Where" doesn't match the quoted excerpt.
- Any affected scrollable is no longer a bottom-reaching mobile surface.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that mobile lists now leave device-aware space after their final item. Open Cache Management and Donate on a gesture-navigation phone and scroll to the end to see it.
