# Fix: Closing a modal can reopen the keyboard behind it

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/unfocus-before-modal
- **Needs new dependency**: none

## Why

Local and SMB file browsers keep a search field in their toolbar while rename and confirmation dialogs open. Login also opens several dialogs from an active form; without clearing the primary focus first, dismissing the modal can restore the old keyboard unexpectedly.

## Where

~~~dart
// lib/screen/local_storage_browser_screen.dart:1695 — current
final result = await showDialog<String>(
  context: context,
  builder: (context) => AlertDialog(
~~~

~~~dart
// lib/screen/local_storage_browser_screen.dart:1726 — current
return await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
~~~

~~~dart
// lib/screen/smb/smb_browser_screen.dart:462 — current
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
~~~

~~~dart
// lib/screen/smb/smb_browser_screen.dart:546 — current
final result = await showDialog<String>(
  context: context,
  builder: (context) => AlertDialog(
~~~

~~~dart
// lib/screen/login_screen.dart:505 — current
SmartDialog.show(builder: (_) {
  return AlertDialog(
    title: Text(Intl.guestModeDialog_title.tr),
~~~

~~~dart
// lib/screen/login_screen.dart:664 — current
SmartDialog.show(
  clickMaskDismiss: false,
  builder: (_) {
    return AlertDialog(
~~~

~~~dart
// lib/screen/login_screen.dart:726 — current
SmartDialog.show(builder: (context) {
  return AlertDialog(
    title: Text(Intl.davTipsDialog_title.tr),
~~~

~~~dart
// lib/widget/app_ui.dart:375 — current
return showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
~~~

## The fix

Immediately before each modal opens, call the article's global primary-focus API:

~~~dart
FocusManager.instance.primaryFocus?.unfocus();
final result = await showDialog<String>(
  // existing dialog unchanged
);
~~~

For the shared bottom-sheet helper, put the call before returning the route Future:

~~~dart
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required List<Widget> children,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<T>(
    // existing arguments unchanged
  );
}
~~~

Never use FocusScope.of(context).unfocus for this fix; the article requires FocusManager because it owns the latest primary focus across nested scopes.

## Steps

1. In local_storage_browser_screen.dart, add the FocusManager call before both _askName's showDialog and _confirm's showDialog.
2. In smb_browser_screen.dart, add it before the delete confirmation dialog and rename/name dialog.
3. In login_screen.dart, add it before the guest-mode dialog, privacy/terms modal, 2FA dialog, and DAV warning dialog. Keep the existing 2FA failure-path call; move it into the modal-opening method if that is the only way to guarantee exactly one call.
4. In lib/widget/app_ui.dart, add it once at the start of showAppBottomSheet so every current and future caller is covered.
5. Do not change focus behavior for normal page navigation or inline validation.

## Check it

- dart analyze exits clean.
- rg -n -B2 "showDialog" lib/screen/local_storage_browser_screen.dart lib/screen/smb/smb_browser_screen.dart shows FocusManager immediately before every listed opener.
- rg -n -B2 "SmartDialog.show" lib/screen/login_screen.dart shows FocusManager before each listed form modal.
- rg -n "FocusManager.instance.primaryFocus" lib/widget/app_ui.dart returns the shared helper call.
- rg -n "FocusScope.of\\(context\\).unfocus" in the edited files returns no newly added matches.

## Don't touch

- Do not clear focus on every tap or before ordinary page navigation.
- Do not remove autofocus from the field inside a rename or 2FA dialog.
- Do not change dialog content, validation, return values, or navigation.
- Do not replace FocusManager with FocusScope.
- No new dependencies.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- A listed modal can no longer be opened while any page field is focused.
- A modal intentionally restores the previous field for a documented workflow.
- The code at any location in "Where" doesn't match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that dialogs now clear the active page field before opening, so closing them does not resurrect the keyboard. Focus the local or SMB search box, open Rename, close it, and confirm the keyboard stays dismissed.
