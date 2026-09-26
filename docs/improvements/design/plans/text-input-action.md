# Fix: Keyboard action keys do not advance or submit every mobile form

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/text-input-action
- **Needs new dependency**: none

## Why

Login has next/next/done behavior, but the shared SMB form field cannot submit from its final field. Search and several one-field dialogs also leave the keyboard action implicit, forcing users to reach for an on-screen button.

## Where

~~~dart
// lib/widget/app_ui.dart:417 — current
this.textInputAction = TextInputAction.next,
this.enabled = true,
~~~

~~~dart
// lib/widget/app_ui.dart:433 — current
child: TextField(
  controller: controller,
  enabled: enabled,
  obscureText: obscureText,
  keyboardType: keyboardType,
  textInputAction: textInputAction,
  decoration: AppUi.fieldDecoration(
~~~

~~~dart
// lib/screen/smb/smb_list_screen.dart:196 — current final field
AppFormField(
  controller: passCtrl,
  label: Intl.smb_label_password.tr,
  obscureText: true,
  textInputAction: TextInputAction.done,
),
~~~

~~~dart
// lib/screen/smb/smb_scan_screen.dart:235 — current final field
AppFormField(
  controller: passCtrl,
  label: Intl.smb_label_password.tr,
  obscureText: true,
  textInputAction: TextInputAction.done,
),
~~~

~~~dart
// lib/screen/file_search_screen.dart:75 — current
child: TextField(
  focusNode: controller.focusNode,
  controller: controller.textEditingController,
  onChanged: (text) {
    controller.onSearchTextChange(text);
  },
~~~

~~~dart
// lib/screen/local_storage_browser_screen.dart:379 — current
child: TextField(
  controller: _searchController,
  focusNode: _searchFocus,
  decoration: InputDecoration(
    hintText: Intl.fileManager_searchHint.tr,
~~~

~~~dart
// lib/screen/smb/smb_browser_screen.dart:199 — current
child: TextField(
  controller: _searchController,
  decoration: InputDecoration(
    hintText: Intl.fileManager_searchHint.tr,
~~~

~~~dart
// lib/screen/file_list/mkdir_dialog.dart:45 — current
content: TextField(
  focusNode: widget.focusNode,
  autofocus: true,
  controller: widget.controller,
~~~

~~~dart
// lib/screen/file_list/file_rename_dialog.dart:45 — current
content: TextField(
  focusNode: widget.focusNode,
  autofocus: true,
  controller: widget.controller,
~~~

~~~dart
// lib/screen/file_list/director_password_dialog.dart:35 — current
TextField(
  controller: _controller,
  obscureText: true,
  focusNode: widget.focusNode,
  autofocus: true,
~~~

~~~dart
// lib/screen/login_screen.dart:669 — current
content: TextField(
  controller: twofaController,
  focusNode: focusNode,
  autofocus: true,
  decoration: const InputDecoration(
~~~

## The fix

Extend AppFormField with the article's submit callback and pass it directly to TextField:

~~~dart
// lib/widget/app_ui.dart — target
const AppFormField({
  // existing arguments
  this.onSubmitted,
});

final ValueChanged<String>? onSubmitted;

TextField(
  // existing arguments
  textInputAction: textInputAction,
  onSubmitted: onSubmitted,
)
~~~

For SMB forms, keep every non-last field at TextInputAction.next. The password field remains done and submits through the exact same Navigator.pop result as the Save button:

~~~dart
AppFormField(
  controller: passCtrl,
  label: Intl.smb_label_password.tr,
  obscureText: true,
  textInputAction: TextInputAction.done,
  onSubmitted: (_) => Navigator.pop(ctx, true),
),
~~~

For all three search fields use `TextInputAction.search` and dismiss the primary focus on submit without changing the query. For one-field create, rename, password, and 2FA dialogs use done and call the same confirm method as the visible primary button.

~~~dart
// all three search fields — target additions
textInputAction: TextInputAction.search,
onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
~~~

The 2FA field must preserve the visible OK button's exact order: dismiss the dialog, then call `_onConfirm(context)`.

~~~dart
// lib/screen/login_screen.dart — target 2FA additions
textInputAction: TextInputAction.done,
onSubmitted: (_) {
  SmartDialog.dismiss();
  _onConfirm(context);
},
~~~

## Steps

1. Add onSubmitted to AppFormField's constructor, field list, and TextField in lib/widget/app_ui.dart.
2. In SmbListScreen's edit form, pass onSubmitted on the final password field to Navigator.pop(ctx, true); keep the Save button unchanged.
3. Do the same in SmbScanScreen's add-host form.
4. Set TextInputAction.search on file_search_screen.dart, local_storage_browser_screen.dart, and smb_browser_screen.dart search fields. On submit, keep the existing query and unfocus the field.
5. Add TextInputAction.done and onSubmitted calling widget.onConfirm to MkdirDialog and FileRenameDialog.
6. Add done and the same confirm path used by the OK button to DirectorPasswordDialog and the login 2FA field.
7. In the local-storage and SMB inline name dialogs, explicitly set done while retaining their existing onSubmitted callbacks.
8. Keep LoginScreen's current next/next/done sequence and final onSubmitted behavior unchanged.

## Check it

- dart analyze exits clean.
- rg -n "onSubmitted" lib/widget/app_ui.dart returns the constructor property and TextField forwarding.
- rg -n -A8 "textInputAction: TextInputAction.done" lib/screen/smb/smb_list_screen.dart lib/screen/smb/smb_scan_screen.dart shows onSubmitted on each final field.
- rg -n "TextInputAction.search" lib/screen/file_search_screen.dart lib/screen/local_storage_browser_screen.dart lib/screen/smb/smb_browser_screen.dart returns one search action per file.
- rg -n "TextInputAction.done|onSubmitted" lib/screen/file_list/mkdir_dialog.dart lib/screen/file_list/file_rename_dialog.dart lib/screen/file_list/director_password_dialog.dart returns both properties in each dialog.

## Don't touch

- Do not add submit actions to multiline editors.
- Do not introduce custom FocusNodes for next behavior; Flutter handles TextInputAction.next.
- Do not change validation, button behavior, controller contents, or result values.
- Do not alter LoginScreen's already-correct sequence.
- No new dependencies.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- A final-field submit and the visible Save/OK button do not share the same safe validation path.
- Any affected field has become multiline.
- The code at any location in "Where" doesn't match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that form action keys now move through fields and submit from the last one, while search keyboards show Search. Add an SMB connection and create or rename a folder using only the keyboard action key.
