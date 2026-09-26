# Fix: Web and desktop routes use a mobile Cupertino slide

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/web-page-transitions
- **Needs new dependency**: none

## Why

GetMaterialApp currently applies a Cupertino transition to every platform. Web and desktop navigation should switch immediately, while Android and iOS retain the app's existing mobile transition behavior.

## Where

~~~dart
// lib/main.dart:63 — current
return GetMaterialApp(
  initialRoute: NamedRouter.root,
  translations: AlistTranslations(),
  fallbackLocale: const Locale('en', 'US'),
  locale: PlatformDispatcher.instance.locale,
  getPages: AlistRouter.screens,
  builder: _routerBuilder,
  navigatorObservers: [FlutterSmartDialog.observer],
  defaultTransition: Transition.cupertino,
~~~

~~~dart
// lib/main.dart:104 — current dark theme start
ThemeData _dartTheme(BuildContext context) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: darkColorScheme,
~~~

~~~dart
// lib/main.dart:133 — current light theme start
ThemeData _lightTheme(BuildContext context) {
  return ThemeData(
    useMaterial3: true,
    hintColor: const Color(0xFFBBBBBB),
    colorScheme: lightColorScheme,
~~~

## The fix

Create the article's platform transition theme:

~~~dart
// lib/widget/app_page_transitions.dart — target
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const PageTransitionsTheme appPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: kIsWeb
        ? NoPageTransitionsBuilder()
        : ZoomPageTransitionsBuilder(),
    TargetPlatform.iOS: kIsWeb
        ? NoPageTransitionsBuilder()
        : CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: NoPageTransitionsBuilder(),
    TargetPlatform.windows: NoPageTransitionsBuilder(),
    TargetPlatform.linux: NoPageTransitionsBuilder(),
    TargetPlatform.fuchsia: NoPageTransitionsBuilder(),
  },
);

class NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
~~~

GetX has its own default transition, so disable that layer on the same platforms while preserving the current Cupertino transition on mobile:

~~~dart
// lib/main.dart — target GetMaterialApp field
defaultTransition: kIsWeb || GetPlatform.isDesktop
    ? Transition.noTransition
    : Transition.cupertino,
~~~

Assign the shared pageTransitionsTheme to both themes:

~~~dart
pageTransitionsTheme: appPageTransitionsTheme,
~~~

## Steps

1. Create lib/widget/app_page_transitions.dart exactly as shown.
2. Import flutter/foundation.dart and app_page_transitions.dart in lib/main.dart; flutter/foundation.dart is already present, so do not duplicate it.
3. Replace the unconditional GetX Cupertino default with the web/desktop noTransition branch shown above.
4. Add appPageTransitionsTheme to both _dartTheme and _lightTheme.
5. Keep all GetPage definitions and nested file-list navigators unchanged.

## Check it

- `dart analyze` exits clean.
- `rg -n "NoPageTransitionsBuilder|transitionDuration|reverseTransitionDuration|TargetPlatform.macOS|TargetPlatform.windows|TargetPlatform.linux" lib/widget/app_page_transitions.dart` returns the no-transition implementation and desktop mappings.
- `rg -n "kIsWeb.*GetPlatform.isDesktop|Transition.noTransition|Transition.cupertino" lib/main.dart` returns the adaptive GetX branch.
- `rg -n "pageTransitionsTheme: appPageTransitionsTheme" lib/main.dart` returns exactly two matches.
- `rg -n "defaultTransition: Transition.cupertino" lib/main.dart` returns no matches.

## Don't touch

- Do not change route names, route arguments, nested navigator IDs, or back behavior.
- Do not remove mobile transitions.
- Do not add animations to desktop or web.
- No new dependencies or unrelated theme changes.

## STOP if

- The installed GetX version does not expose Transition.noTransition.
- A route explicitly depends on its transition animation for logic rather than visuals.
- The code at any location in "Where" does not match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that web and desktop pages now open immediately while mobile retains its current slide transition. Navigate between Settings, Downloads, and About on macOS or web to verify the result.
