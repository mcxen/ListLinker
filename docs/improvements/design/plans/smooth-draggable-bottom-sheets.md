# Fix: Short bottom sheets open and close mechanically

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/smooth-draggable-bottom-sheets
- **Needs new dependency**: none

## Why

File-details sheets and the shared short action-sheet helper use Material's fixed route motion. A spring route can preserve fling velocity, follow the user's drag, and settle naturally while leaving scrolling/full-screen sheets on their separate routes.

## Where

~~~dart
// lib/screen/favorite_screen.dart:258 — current
showModalBottomSheet(
  context: context,
  builder: (context) => FileDetailsDialog(
~~~

~~~dart
// lib/screen/favorite_screen.dart:273 — current
showModalBottomSheet(
  context: context,
  builder: (context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SafeArea(
        child: Wrap(
~~~

~~~dart
// lib/screen/recents_screen.dart:249 — current
showModalBottomSheet(
  context: context,
  builder: (context) => FileDetailsDialog(
~~~

~~~dart
// lib/screen/file_list/file_list_screen.dart:1232 — current
showModalBottomSheet(
  context: Get.context!,
  builder: (context) => FileDetailsDialog(
~~~

~~~dart
// lib/widget/app_ui.dart:375 — current
return showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  ),
~~~

## The fix

Create the article's spring-driven popup route as a complete standalone file:

~~~dart
// lib/widget/spring_bottom_sheet.dart — target
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

Future<T?> showSpringBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return Navigator.of(context).push(
    SpringSheetRoute<T>(builder: builder),
  );
}

class SpringSheetRoute<T> extends PopupRoute<T> {
  SpringSheetRoute({
    required this.builder,
    super.settings,
  });

  final WidgetBuilder builder;

  static const SpringDescription _enterSpring = SpringDescription(
    mass: 1,
    stiffness: 438.6,
    damping: 41.9,
  );
  static const SpringDescription _exitSpring = SpringDescription(
    mass: 1,
    stiffness: 987.0,
    damping: 62.8,
  );
  static const double _overdragResistance = 100;
  static const double _closeVelocity = 0.9;
  static const double _closePosition = 0.5;

  double? _releaseVelocity;
  bool _popped = false;

  @override
  Color? get barrierColor => const Color(0x8A000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration =>
      const Duration(milliseconds: 200);

  @override
  Animation<double>? get animation {
    final raw = super.animation;
    return raw == null ? null : _ClampedAnimation(raw);
  }

  @override
  AnimationController createAnimationController() {
    return AnimationController.unbounded(
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
      vsync: navigator!,
    );
  }

  @override
  Simulation? createSimulation({required bool forward}) {
    final velocity = _releaseVelocity ?? 0;
    _releaseVelocity = null;
    return SpringSimulation(
      forward ? _enterSpring : _exitSpring,
      controller?.value ?? 0,
      forward ? 1 : 0,
      -velocity,
      snapToEnd: true,
    );
  }

  @override
  bool didPop(T? result) {
    _popped = true;
    return super.didPop(result);
  }

  void _dragBy(double relativeDelta) {
    if (_popped) return;
    final animationController = controller!;
    var delta = relativeDelta;
    if (animationController.value > 1) {
      final overshoot = animationController.value - 1;
      delta *= 1 / (1 + overshoot * _overdragResistance);
    }
    animationController.value -= delta;
  }

  void _endDrag(double relativeVelocity) {
    if (_popped) return;
    final animationController = controller!;
    final value = animationController.value;

    if (value > 1) {
      final overshoot = value - 1;
      final damped =
          relativeVelocity / (1 + overshoot * _overdragResistance);
      animationController.animateWith(
        SpringSimulation(
          _enterSpring,
          value,
          1,
          -damped,
          snapToEnd: true,
        ),
      );
      return;
    }

    final close = switch (relativeVelocity) {
      > _closeVelocity => true,
      < -_closeVelocity => false,
      _ => value < _closePosition,
    };
    if (close) {
      _releaseVelocity = relativeVelocity;
      navigator?.pop();
    } else {
      animationController.animateWith(
        SpringSimulation(
          _enterSpring,
          value,
          1,
          -relativeVelocity,
          snapToEnd: true,
        ),
      );
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedBuilder(
        animation: controller!,
        builder: (context, child) {
          return FractionalTranslation(
            translation: Offset(0, 1 - controller!.value),
            child: child,
          );
        },
        child: Builder(
          builder: (context) {
            double height() => context.size?.height ?? 1;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onVerticalDragUpdate: (details) {
                _dragBy(details.primaryDelta! / height());
              },
              onVerticalDragEnd: (details) {
                _endDrag(details.velocity.pixelsPerSecond.dy / height());
              },
              onVerticalDragCancel: () => _endDrag(0),
              child: SizedBox(
                width: double.infinity,
                child: SheetContainer(child: builder(context)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SheetContainer extends StatelessWidget {
  const SheetContainer({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: child,
        ),
      ),
    );
  }
}

class _ClampedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ClampedAnimation(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);
}
~~~

Replace only short, non-scrolling sheets:

~~~dart
showSpringBottomSheet<void>(
  context: context,
  builder: (context) => FileDetailsDialog(
    // existing arguments unchanged
  ),
);
~~~

Change showAppBottomSheet to call showSpringBottomSheet while preserving its handle, SafeArea, padding, mainAxisSize.min Column, children, and generic result. If earlier plans already added `FocusManager.instance.primaryFocus?.unfocus()` or `HapticsHelper.light()` before the route call, keep each prelude exactly once and in the same order.

## Steps

1. Create lib/widget/spring_bottom_sheet.dart with the complete route, container, and clamped animation above.
2. Import it in favorite_screen.dart, recents_screen.dart, file_list_screen.dart, and app_ui.dart.
3. Replace the three FileDetailsDialog showModalBottomSheet calls with showSpringBottomSheet.
4. Replace FavoriteScreen's non-scrolling Wrap action menu with showSpringBottomSheet and leave every tile and callback unchanged.
5. Replace showAppBottomSheet's route call with showSpringBottomSheet, keeping its builder content unchanged and retaining any existing focus-dismiss or haptic prelude exactly once.
6. Leave the audio playlist, player selector grids, task-count picker, isScrollControlled long file-action menus, and copy/move flow on their current route; they scroll or occupy most of the screen and do not belong to this short-sheet route.

## Check it

- dart analyze exits clean.
- rg -n "class SpringSheetRoute|438.6|987.0|_closeVelocity = 0.9" lib/widget/spring_bottom_sheet.dart returns the route values.
- rg -n "showSpringBottomSheet" lib/screen/favorite_screen.dart lib/screen/recents_screen.dart lib/screen/file_list/file_list_screen.dart lib/widget/app_ui.dart returns one migrated call in each file.
- rg -n "showModalBottomSheet" in the three screen files still returns only scrolling or isScrollControlled long-content sheets, not FileDetailsDialog or FavoriteScreen's short action menu.

## Don't touch

- Do not migrate a sheet containing ListView, GridView, CupertinoPicker, or another scrollable.
- Do not change FileDetailsDialog content or action-menu behavior.
- Do not use this route for the full-screen copy/move flow.
- Do not add a package for the spring route.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- The installed Flutter version does not support PopupRoute.createSimulation or SpringSimulation snapToEnd.
- Any target sheet now contains a scrollable.
- The code at any location in "Where" doesn't match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that short details and action sheets now track drag velocity and settle with a spring. Open file details, drag the sheet partway, and release it slowly and with a fling.
