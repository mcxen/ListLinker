# Fix: Swipe actions stay hidden on several mobile lists

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/flutter-slidable-controller
- **Needs new dependency**: none; flutter_slidable and SpUtil are already installed

## Why

The cloud file list previews its swipe actions once, but Recents, Favorites, Downloads, and Accounts do not. Users who never try a horizontal gesture can miss destructive and detail actions on those screens.

## Where

~~~dart
// lib/screen/file_list/file_list_screen.dart:1093 — current
late final SlidableController _slidableHintController;
bool _hintScheduled = false;
~~~

~~~dart
// lib/screen/favorite_screen.dart:111 — current
return Slidable(
  key: Key(record.path),
  endActionPane: ActionPane(
~~~

~~~dart
// lib/screen/recents_screen.dart:111 — current
return Slidable(
  key: Key(record.path),
  endActionPane: ActionPane(
~~~

~~~dart
// lib/screen/download_manager_screen.dart:146 — current
return Slidable(
  key: Key(downloadItem.id.toString()),
  endActionPane: ActionPane(
~~~

~~~dart
// lib/screen/account_screen.dart:280 — current
return Slidable(
  key: Key(data.id?.toString() ?? ""),
  endActionPane: ActionPane(
~~~

## The fix

Move the existing one-time preview pattern into one reusable wrapper:

~~~dart
// lib/widget/app_slidable.dart — target
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:sp_util/sp_util.dart';

class AppSlidable extends StatefulWidget {
  const AppSlidable({
    super.key,
    required this.child,
    this.startActionPane,
    this.endActionPane,
    this.hintPreferenceKey,
  });

  final Widget child;
  final ActionPane? startActionPane;
  final ActionPane? endActionPane;
  final String? hintPreferenceKey;

  @override
  State<AppSlidable> createState() => _AppSlidableState();
}

class _AppSlidableState extends State<AppSlidable>
    with SingleTickerProviderStateMixin {
  late final SlidableController _controller;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = SlidableController(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleHint();
  }

  void _scheduleHint() {
    final preferenceKey = widget.hintPreferenceKey;
    if (_scheduled ||
        preferenceKey == null ||
        SpUtil.getBool(preferenceKey) == true) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _runHint(preferenceKey));
  }

  Future<void> _runHint(String preferenceKey) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (widget.endActionPane != null) {
      await _controller.openEndActionPane(
        duration: const Duration(milliseconds: 400),
      );
    } else if (widget.startActionPane != null) {
      await _controller.openStartActionPane(
        duration: const Duration(milliseconds: 400),
      );
    } else {
      return;
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _controller.close(duration: const Duration(milliseconds: 300));
    await SpUtil.putBool(preferenceKey, true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Slidable(
      controller: _controller,
      startActionPane: widget.startActionPane,
      endActionPane: widget.endActionPane,
      child: widget.child,
    );
  }
}
~~~

Add page-specific preference keys in AlistConstant:

~~~dart
// lib/util/constant.dart — target
static const slidableHintShown = 'slidableHintShown';
static const recentsSlidableHintShown = 'recentsSlidableHintShown';
static const favoritesSlidableHintShown = 'favoritesSlidableHintShown';
static const downloadsSlidableHintShown = 'downloadsSlidableHintShown';
static const accountsSlidableHintShown = 'accountsSlidableHintShown';
~~~

Replace each affected Slidable with AppSlidable and pass a preference key only for index zero. Recents becomes:

~~~dart
// lib/screen/recents_screen.dart — target
return AppSlidable(
  key: Key(record.path),
  hintPreferenceKey:
      index == 0 ? AlistConstant.recentsSlidableHintShown : null,
  endActionPane: ActionPane(
    motion: const DrawerMotion(),
    children: [
      SlidableAction(
        onPressed: (context) => _showDetailsDialog(context, record),
        backgroundColor: Get.theme.colorScheme.secondary,
        foregroundColor: Colors.white,
        label: Intl.recentsScreen_menu_details.tr,
      ),
      SlidableAction(
        onPressed: (context) => _deleteRecord(record),
        backgroundColor: const Color(0xFFFE4A49),
        foregroundColor: Colors.white,
        label: Intl.recentsScreen_menu_delete.tr,
      ),
    ],
  ),
  child: FileListItemView(
    icon: FileUtils.getFileIcon(false, record.name),
    fileName: record.name,
    thumbnail: record.thumb,
    time: FileUtils.getReformatTime(createTime, ""),
    sizeDesc: FileUtils.formatBytes(record.size),
    onTap: () => _onFileTap(context, record, false),
    onMoreIconButtonTap: () => _showBottomMenuDialog(context, record),
  ),
);
~~~

Change _fileListItemView to accept int index and call it with item from ListView.separated. Apply the same mechanical wrapper substitution with the matching key for Files, Favorites, Downloads, and Accounts; their current ActionPane and child blocks are copied verbatim.

## Steps

1. Create lib/widget/app_slidable.dart with the complete implementation above.
2. Add the four new page-specific keys to lib/util/constant.dart; retain slidableHintShown for the file list.
3. In file_list_screen.dart, replace Slidable with AppSlidable, pass slidableHintShown only at index zero, and remove its local controller, scheduler, initState, and dispose code.
4. In favorite_screen.dart, pass the list index into _fileListItemView and replace Slidable with AppSlidable using favoritesSlidableHintShown at index zero.
5. In recents_screen.dart, pass the list index into _fileListItemView and use recentsSlidableHintShown at index zero.
6. In download_manager_screen.dart, use the existing index parameter and downloadsSlidableHintShown at index zero.
7. In account_screen.dart, thread index through both list-building paths and _ListItem, then use accountsSlidableHintShown at index zero.
8. Keep every ActionPane, extentRatio, motion, action callback, key value, SlidableAutoCloseBehavior, and row child unchanged.

## Check it

- dart analyze exits clean.
- rg -n "class AppSlidable|openEndActionPane|milliseconds: 900|putBool" lib/widget/app_slidable.dart returns all preview stages.
- rg -n "SlidableHintShown" lib/util/constant.dart returns all five preference keys.
- rg -n "AppSlidable" in each of the five affected screen files returns at least one use.
- rg -n "SlidableController|_maybeShowSlidableHint|_hintScheduled" lib/screen/file_list/file_list_screen.dart returns no matches.

## Don't touch

- Do not change what any swipe action does, its color, label, side, or extent.
- Do not preview more than the first row on a page.
- Do not reset an existing preference or show a hint more than once per page.
- Do not add the once package; persistence already exists through SpUtil.
- No new dependencies.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- Any affected list no longer exposes its builder index at the Slidable call.
- The installed flutter_slidable controller API does not accept the duration arguments shown above.
- The code at any location in "Where" doesn't match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that the first row in each swipe-enabled mobile list now briefly reveals and closes its actions once. Visit Recents, Favorites, Downloads, Accounts, and the cloud file list with fresh preferences to see it.
