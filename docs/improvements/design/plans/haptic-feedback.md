# Fix: Mobile selection, toggle, and long-press moments feel silent

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/haptic-feedback
- **Needs new dependency**: `haptic_feedback: ^0.6.5`, for semantic success, warning, error, soft, and selection feedback with a shared capability check

## Why

Bottom navigation and login already use Flutter's generic haptics, but checkboxes, swipe-related long presses, audio-track selection, and several shared controls remain silent. A single capability-aware helper gives these moments consistent semantic feedback without vibrating unsupported devices.

## Where

~~~dart
// lib/screen/home_screen.dart:75 — current
HapticFeedback.selectionClick();
~~~

~~~dart
// lib/screen/home_screen.dart:286 — current long-press path
onLongPress: (int idx) {
  LogUtil.d("onDoubleTap: $idx");
  final destination = _mobileDestinations[idx];
  if (destination == _HomeDestination.cloud &&
      _currentDestination == _HomeDestination.cloud) {
    Get.until((route) => route.isFirst,
        id: AlistRouter.fileListRouterStackId);
  } else {
    _onDestinationSelected(destination);
  }
},
~~~

~~~dart
// lib/widget/app_ui.dart:228 — current
onTap: onTap == null
    ? null
    : () {
        HapticFeedback.selectionClick();
        onTap!();
      },
onLongPress: onLongPress,
~~~

~~~dart
// lib/widget/app_ui.dart:307 — current AppActionCard tap
child: InkWell(
  onTap: () {
    HapticFeedback.selectionClick();
    onTap();
  },
~~~

~~~dart
// lib/widget/app_ui.dart:371 — current short-sheet helper
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required List<Widget> children,
}) {
  return showModalBottomSheet<T>(
~~~

~~~dart
// lib/screen/login_screen.dart:174 — current
HapticFeedback.lightImpact();
~~~

~~~dart
// lib/screen/login_screen.dart:163 — current keyboard submit
onSubmitted: (_) {
  loginScreenController.twofaController.text = "";
  KeyboardUtil.hideKeyboard(context);
  loginScreenController.onLoginButtonClick(context);
},
~~~

~~~dart
// lib/screen/login_screen.dart:184 — current guest submit
FilledButton(
  style: FilledButton.styleFrom(
    backgroundColor: Theme.of(context).colorScheme.secondary,
  ),
  onPressed: () {
    final address =
        loginScreenController.addressController.text.trim();
~~~

~~~dart
// lib/screen/login_screen.dart:223 — current
Checkbox(
  value: loginScreenController.ignoreSSLError.value,
  onChanged: (checked) {
    loginScreenController.setIgnoreSSLError(checked ?? false);
  },
),
~~~

~~~dart
// lib/screen/file_list/director_password_dialog.dart:50 — current
Checkbox(
  value: _isRememberPassword,
  onChanged: (checked) {
    setState(() {
      _isRememberPassword = checked ?? false;
    });
  },
),
~~~

~~~dart
// lib/screen/local_storage_browser_screen.dart:783 — current
child: Checkbox(
  value: selected,
  onChanged: (_) => _toggleEntry(entry),
),
~~~

~~~dart
// lib/widget/player_skin.dart:1381 — current
Checkbox(
  value: index == i,
  onChanged: (checked) {
    if (checked == true) {
      callback(i);
    }
  },
),
~~~

~~~dart
// lib/widget/player_skin.dart:1003 — current double-speed hold
GestureLongPressCallback? _onLongPressStart() {
  return _locked
      ? null
      : () {
          if (_fullscreen &&
              _playing &&
              _duration.inMilliseconds > 0 &&
              _rate < 2.0) {
            setState(() {
              _longPressRating = true;
            });
            _player.setRate(2.0);
          }
        };
}
~~~

~~~dart
// lib/widget/alist_checkbox.dart:20 — current
CupertinoCheckbox(
  value: value,
  onChanged: onChanged,
),
~~~

~~~dart
// lib/widget/file_list_item_view.dart:80 — current
onLongPress: onMoreIconButtonTap,
~~~

~~~dart
// lib/screen/download_manager_screen.dart:144 — current
onLongPress: onLongPress,
~~~

~~~dart
// lib/screen/account_screen.dart:146 — current confirmed deletion
TextButton(
  onPressed: () {
    SmartDialog.dismiss();
    _deleteAccount(list, item);
  },
  child: Text(Intl.deleteAccountDialog_btn_ok.tr),
),
~~~

~~~dart
// lib/screen/cache_manager.dart:24 — current direct cache clears
ListTile(
  title: Text(Intl.cacheManagement_imageCache.tr),
  subtitle: Obx(() => Text(controller.imageCacheSizeStr.value)),
  onTap: () {
    controller.clearImageCache();
  },
),
// The audio and other cache rows use the same direct onTap shape.
~~~

## The fix

Add the article's capability-caching helper:

~~~dart
// lib/util/haptics_helper.dart — target
import 'package:haptic_feedback/haptic_feedback.dart';

class HapticsHelper {
  HapticsHelper._();

  static bool? _canVibrate;

  static Future<void> _vibrate(HapticsType type) async {
    try {
      final canVibrate = _canVibrate ??= await Haptics.canVibrate();
      if (!canVibrate) return;
      await Haptics.vibrate(type);
    } catch (_) {
      // Haptics are optional and must never block the user's action.
    }
  }

  static Future<void> success() => _vibrate(HapticsType.success);
  static Future<void> warning() => _vibrate(HapticsType.warning);
  static Future<void> error() => _vibrate(HapticsType.error);
  static Future<void> light() => _vibrate(HapticsType.light);
  static Future<void> medium() => _vibrate(HapticsType.medium);
  static Future<void> heavy() => _vibrate(HapticsType.heavy);
  static Future<void> soft() => _vibrate(HapticsType.soft);
  static Future<void> selection() => _vibrate(HapticsType.selection);
}
~~~

Apply these pairings:

- selection: bottom-navigation changes, AppListTile/AppActionCard taps, and audio-track choice.
- light: login button, login keyboard submit, guest submission, and opening a short bottom sheet.
- soft: every checkbox toggle, including taps on its text label.
- medium: long-press menus and the player's hold-for-double-speed gesture.
- heavy: confirming account deletion or starting one of the current direct cache-category clears. The cache screen has no confirmation UI; do not invent one in this plan.

Call the helper once in the shared method when a checkbox and its label share the same state change. Do not call from both the Checkbox and label callbacks.

## Steps

1. Run `flutter pub add 'haptic_feedback:^0.6.5'`; version 0.6.5 supports Dart 3 and exposes every `HapticsType` used below.
2. Create lib/util/haptics_helper.dart with the complete helper above.
3. Replace all direct HapticFeedback calls in home_screen.dart, login_screen.dart, and app_ui.dart with the matching HapticsHelper methods; remove flutter/services.dart imports only when no other service APIs remain.
4. Add light to LoginScreen's password-field onSubmitted and guest-button callback. Keep the login button's existing single light event by replacing, not supplementing, its direct call. Do not move this feedback into onLoginButtonClick because redirects, 2FA retries, and DAV retries also call that method and would vibrate twice.
5. Add light once in showAppBottomSheet before returning its route Future. If `FocusManager.instance.primaryFocus?.unfocus()` is already present from earlier work, preserve it first, then trigger light, then open the route.
6. Add a single soft call inside LoginScreenController.setIgnoreSSLError so both checkbox and label taps share it.
7. Add a _setRememberPassword helper in director_password_dialog.dart that triggers soft once and updates state; route both checkbox and label through it.
8. Add soft once inside LocalStorageBrowser's _toggleEntry method so both list and grid checkboxes are covered.
9. In the audio-track selector, add selection immediately before callback(i) in both gesture and checkbox paths, guarded by index != i so an already-selected item stays silent.
10. In AlistCheckBox, wrap onChanged in one private callback that triggers soft and forwards the value.
11. Wrap FileListItemView and DownloadManager long-press callbacks so medium fires immediately before the existing callback.
12. In the player, fire medium only inside the eligibility if block immediately before switching to 2x; an ineligible hold stays silent.
13. At the start of the custom bottom-navigation long-press callback, fire medium. Add an optional emitHaptic flag to _onDestinationSelected, defaulting to true; the long-press branch passes false when it delegates there so it does not also fire selection.
14. Add heavy immediately after SmartDialog.dismiss and before _deleteAccount in the account confirmation button. Add heavy immediately before each of the three direct controller.clear... calls in CacheManagerScreen; do not add a new cache confirmation dialog.

## Check it

- dart analyze exits clean.
- rg -n "haptic_feedback" pubspec.yaml lib/util/haptics_helper.dart returns the dependency and import.
- rg -n "class HapticsHelper|Haptics.canVibrate|HapticsType.soft|HapticsType.selection|catch \(_\)" lib/util/haptics_helper.dart returns all helper behavior and the non-blocking failure guard.
- rg -n "HapticFeedback" lib/screen/home_screen.dart lib/screen/login_screen.dart lib/widget/app_ui.dart returns no matches.
- rg -n "HapticsHelper.light" lib/screen/login_screen.dart lib/widget/app_ui.dart returns login button, keyboard, guest, and shared short-sheet coverage.
- rg -n "HapticsHelper.soft" in the checkbox-owning files returns one shared state-change call per control family.
- rg -n "HapticsHelper.medium" lib/screen/home_screen.dart lib/widget/file_list_item_view.dart lib/screen/download_manager_screen.dart lib/widget/player_skin.dart returns the long-press coverage.
- rg -n "HapticsHelper.heavy" lib/screen/account_screen.dart lib/screen/cache_manager.dart returns one confirmed account deletion and three direct cache clears.

## Don't touch

- Do not vibrate on passive loading, automatic navigation, timer ticks, or every toast.
- Do not trigger twice when a label delegates to the same checkbox state change.
- Do not block an action if the platform cannot vibrate or the haptic call fails.
- Do not change control values, callbacks, labels, or navigation.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- haptic_feedback cannot resolve with the repository's Flutter SDK or target platforms.
- A state-changing callback is shared with non-user-initiated updates; do not add haptics to that shared path without splitting it.
- The code at any location in "Where" doesn't match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that navigation, selectors, checkboxes, and long-press actions now use restrained semantic haptics. Try the SSL checkbox, select a local file, and long-press a file row on a physical phone.
