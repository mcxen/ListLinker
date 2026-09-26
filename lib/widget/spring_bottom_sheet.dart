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
  SpringSheetRoute({required this.builder, super.settings});

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
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

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
      final damped = relativeVelocity / (1 + overshoot * _overdragResistance);
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
  const SheetContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
