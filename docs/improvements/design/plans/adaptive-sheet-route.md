# Fix: Large file-operation sheets use an old mechanical full-screen route

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/adaptive-sheet-route
- **Needs new dependency**: `stupid_simple_sheet: ^0.9.1`, for the article's iOS glass sheet and adaptive non-iOS sheet routes

## Why

Copy/move and long file-action flows can fill most of a phone screen but still use showModalBottomSheet or Get.bottomSheet. They open mechanically, lack a modern fully rounded modal surface, and use back-style chrome where a full-screen modal should provide a close affordance.

## Where

~~~dart
// lib/screen/file_list/file_list_screen.dart:677 — current
showModalBottomSheet(
  context: Get.context!,
  isScrollControlled: true,
  builder: (context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SafeArea(
        child: Wrap(
~~~

~~~dart
// lib/screen/recents_screen.dart:271 — current
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SafeArea(
        child: Wrap(
~~~

~~~dart
// lib/screen/file_list/file_list_screen.dart:818 — current
var future = Get.bottomSheet(
  FileCopyMoveDialog(
    originalFolder: originalFolder,
    names: [file.name],
    isCopy: isCopy,
  ),
  isScrollControlled: true,
);
~~~

~~~dart
// lib/screen/file_list/file_copy_move_dialog.dart:97 — current
AppBar(
  leading: BackButton(
    onPressed: () {
      if (_key?.currentState != null &&
          _key?.currentState?.canPop() == true) {
        _key?.currentState?.pop();
      } else {
        Get.back();
      }
    },
),
~~~

~~~dart
// lib/screen/file_list/file_copy_move_dialog.dart:426 — current result return
Get.back(result: {"result": true});
~~~

## The fix

Add the article's adaptive route extension:

~~~dart
// lib/widget/adaptive_sheet_route.dart — target
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stupid_simple_sheet/stupid_simple_sheet.dart';

extension AdaptiveSheetRouteX on Widget {
  Route<T> asAdaptiveSheetRoute<T>() {
    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    if (isIos) {
      return StupidSimpleGlassSheetRoute<T>(
        child: this,
        blurBehindBarrier: false,
      );
    }
    return StupidSimpleSheetRoute<T>(child: this);
  }
}
~~~

Add a reusable full-screen frame for long action lists:

~~~dart
// lib/widget/adaptive_sheet_page.dart — target
import 'package:flutter/material.dart';

class AdaptiveSheetPage extends StatelessWidget {
  const AdaptiveSheetPage({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
~~~

Push long action content with Navigator:

~~~dart
final result = await Navigator.of(context).push<T>(
  AdaptiveSheetPage(
    child: existingActionColumn,
  ).asAdaptiveSheetRoute<T>(),
);
~~~

Push FileCopyMoveDialog directly through asAdaptiveSheetRoute and keep its result Future. Its inner `Navigator` must remain separate from the outer sheet route. Capture both contexts explicitly when each nested page is built:

~~~dart
// lib/screen/file_list/file_copy_move_dialog.dart — target route shape
return SizedBox(
  // existing size and AlistWillPopScope
  child: Navigator(
    key: _key,
    onGenerateRoute: (settings) {
      // existing path and controller setup
      return GetPageRoute(
        page: () => Builder(
          builder: (nestedContext) => _buildFileListColumn(
            sheetContext: context,
            nestedContext: nestedContext,
            controller: controller,
            path: path!,
          ),
        ),
      );
    },
  ),
);
~~~

Use the nested route's own context for folder back and the captured outer context for close. Each nested page is built at a fixed navigation depth, so `Navigator.of(nestedContext).canPop()` gives the correct leading state without converting the dialog to StatefulWidget or adding a route observer:

~~~dart
// FileCopyMoveDialog AppBar — target navigation split
final folderNavigator = Navigator.of(nestedContext);
final canPopFolder = folderNavigator.canPop();

AppBar(
  automaticallyImplyLeading: false,
  leading: canPopFolder
      ? BackButton(onPressed: folderNavigator.pop)
      : null,
  title: Text(name),
  actions: [
    IconButton(
      tooltip: MaterialLocalizations.of(sheetContext).closeButtonTooltip,
      onPressed: () => Navigator.of(sheetContext).pop(),
      icon: const Icon(Icons.close_rounded),
    ),
  ],
)
~~~

Finally, give every per-path FileCopyMoveController the same outer completion callback and replace its success-path `Get.back(result: ...)` with that callback. This prevents GetX from choosing the nested navigator and preserves the exact `{"result": true}` Future result:

~~~dart
// FileCopyMoveController — target result contract
FileCopyMoveController(
  originalFolder,
  names,
  isCopy,
  path,
  onCompleted: (result) {
    Navigator.of(sheetContext).pop(result);
  },
);

// constructor and field
FileCopyMoveController(
  this.originalFolder,
  this.names,
  this.isCopy,
  this.path, {
  required this.onCompleted,
});

final ValueChanged<Map<String, bool>> onCompleted;

// in httpCopyMove success
onCompleted({"result": true});
~~~

## Steps

1. Run `flutter pub add 'stupid_simple_sheet:^0.9.1'`; the current `0.9.1+1` release supports Dart 3.5 and exports both route classes used below.
2. Create lib/widget/adaptive_sheet_route.dart with AdaptiveSheetRouteX exactly as shown.
3. Create lib/widget/adaptive_sheet_page.dart with the complete rounded-sheet content frame and close button above.
4. In file_list_screen.dart, extract the current isScrollControlled action Wrap into a widget, place it in AdaptiveSheetPage, and push its adaptive route. Preserve every existing action and pop-before-action order.
5. Make the same migration for RecentsScreen's isScrollControlled action menu.
6. Replace Get.bottomSheet for FileCopyMoveDialog with Navigator.of(context).push using FileCopyMoveDialog(...).asAdaptiveSheetRoute.
7. In FileCopyMoveDialog, pass both `sheetContext` and a Builder-provided `nestedContext` into each generated folder page. Use nestedContext only for folder back and sheetContext only for close.
8. Disable automatic AppBar leading. Show a leading BackButton only when the nested page can pop, and replace the trailing Cancel text with an always-visible close X that pops the outer sheet.
9. Add a required `ValueChanged<Map<String, bool>> onCompleted` callback to FileCopyMoveController. Pass the outer pop callback when constructing every per-path controller, and replace the success-path Get.back call with `onCompleted({"result": true})`.
10. Preserve the caller's Future result check used to request a file-list refresh after a successful copy or move.
11. Leave short details sheets and small non-scrolling action sheets for the spring-bottom-sheet plan.

## Check it

- dart analyze exits clean.
- rg -n "stupid_simple_sheet" pubspec.yaml lib/widget/adaptive_sheet_route.dart returns the dependency and import.
- rg -n "StupidSimpleGlassSheetRoute|StupidSimpleSheetRoute|blurBehindBarrier: false" lib/widget/adaptive_sheet_route.dart returns all adaptive branches.
- rg -n "RoundedRectangleBorder|Radius.circular\(28\)|Clip.antiAlias" lib/widget/adaptive_sheet_page.dart returns the non-iOS rounded surface.
- rg -n "AdaptiveSheetPage|asAdaptiveSheetRoute" lib/screen/file_list/file_list_screen.dart lib/screen/recents_screen.dart returns each migrated flow.
- rg -n "Get.bottomSheet|isScrollControlled: true" lib/screen/file_list/file_list_screen.dart lib/screen/recents_screen.dart returns no matches for the three target flows.
- rg -n "sheetContext|nestedContext|automaticallyImplyLeading: false|close_rounded|onCompleted" lib/screen/file_list/file_copy_move_dialog.dart returns the outer/inner navigation split and explicit result callback.
- rg -n "Get.back\(result:" lib/screen/file_list/file_copy_move_dialog.dart returns no matches.

## Don't touch

- Do not move the Git/GetX navigation stacks used inside FileCopyMoveDialog.
- Do not alter file actions, permissions, copy/move arguments, result maps, or refresh behavior.
- Do not migrate short FileDetailsDialog sheets to this route.
- Do not use the adaptive route for the audio playlist or picker sheets without a separate scroll-coordination design.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- stupid_simple_sheet cannot resolve with the current Flutter SDK or does not expose the two route classes from the article.
- FileCopyMoveDialog's result cannot be returned intact through Navigator.push.
- Nested folder navigation cannot be separated from closing the modal without changing behavior.
- The code at any location in "Where" doesn't match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that large file-action and copy/move flows now use modern adaptive sheets with a clear close control. Open a file's long action menu and start Copy or Move on both iOS and Android to see the platform-appropriate route.
