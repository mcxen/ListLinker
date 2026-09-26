# Fix: The keyboard stays open while forms and search results scroll

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/dismiss-keyboard-on-scroll
- **Needs new dependency**: none

## Why

Login already dismisses the keyboard on drag, but SMB connection forms and three searchable file views do not. On a phone, the keyboard can continue covering half the form or results after the user starts scrolling to read.

## Where

~~~dart
// lib/screen/login_screen.dart:52 — correct exemplar
child: SingleChildScrollView(
  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
  child: LoginScreenContainer(),
),
~~~

~~~dart
// lib/screen/smb/smb_scan_screen.dart:203 — current
child: SingleChildScrollView(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppFormField(
~~~

~~~dart
// lib/screen/smb/smb_list_screen.dart:166 — current
child: SingleChildScrollView(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppFormField(
~~~

~~~dart
// lib/screen/file_search_screen.dart:114 — current
return Obx(() => ListView.separated(
  padding: WidgetUtils.listViewPadding(context),
~~~

~~~dart
// lib/screen/local_storage_browser_screen.dart:734 — current
child: ListView.builder(
  padding: EdgeInsets.only(
~~~

~~~dart
// lib/screen/local_storage_browser_screen.dart:856 — current
return GridView.builder(
  padding: EdgeInsets.fromLTRB(
~~~

~~~dart
// lib/screen/smb/smb_browser_screen.dart:255 — current
return ListView.separated(
  padding: EdgeInsets.only(
~~~

## The fix

Set the article's built-in behavior on every affected scrollable:

~~~dart
keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
~~~

For the SMB dialogs, place it directly on SingleChildScrollView. For file search, local storage list/grid, and SMB browser, place it on the result scrollable even though the search field sits in a fixed toolbar; dragging the result set still means the user has finished typing.

## Steps

1. Add keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag to the SMB scan connection-form SingleChildScrollView.
2. Add the same behavior to the saved-SMB connection edit-form SingleChildScrollView.
3. Add it to FileSearchScreen's result ListView.separated.
4. Add it to both LocalStorageBrowser's ListView.builder and GridView.builder so view-mode changes do not change keyboard behavior.
5. Add it to SmbBrowserScreen's result ListView.separated.
6. Keep LoginScreen's existing onDrag behavior unchanged.

## Check it

- dart analyze exits clean.
- rg -n "keyboardDismissBehavior" lib/screen/smb/smb_scan_screen.dart lib/screen/smb/smb_list_screen.dart lib/screen/file_search_screen.dart lib/screen/local_storage_browser_screen.dart lib/screen/smb/smb_browser_screen.dart returns one match per affected scrollable, with two in local_storage_browser_screen.dart.
- rg -n "keyboardDismissBehavior" lib/screen/login_screen.dart still returns its existing match.

## Don't touch

- Do not add this behavior to chat-style or media-playlist scrolling.
- Do not change text controllers, focus nodes, search debounce, form validation, or result filtering.
- Do not wrap the screens in a new GestureDetector.
- No new dependencies.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- Any listed scrollable no longer shares a page or modal with the quoted input flow.
- The code at any location in "Where" doesn't match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that dragging SMB forms and file-search results now dismisses the keyboard. Try each search and scroll the results on a phone with the keyboard open.
