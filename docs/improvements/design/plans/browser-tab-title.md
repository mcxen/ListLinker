# Fix: Every Flutter Web page keeps the same browser tab title

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/browser-tab-title
- **Needs new dependency**: none

## Why

The app sets one static title and never updates it as GetX navigation changes. Browser tabs, history entries, and bookmarks therefore cannot identify the active ListLinker page.

## Where

~~~dart
// lib/main.dart:68 — current route builder hook
getPages: AlistRouter.screens,
builder: _routerBuilder,
navigatorObservers: [FlutterSmartDialog.observer],
~~~

~~~dart
// lib/main.dart:73 — current static fallback title
title: "ALClient",
~~~

~~~dart
// lib/main.dart:88 — current shared builder result
return MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaleFactor: 1),
  child: RefreshConfiguration(
      headerBuilder: () {
        return ClassicHeader(
          idleText: Intl.pullRefresh_idleRefreshText.tr,
          releaseText: Intl.pullRefresh_canRefreshText.tr,
          refreshingText: Intl.pullRefresh_refreshingText.tr,
          completeText: Intl.pullRefresh_refreshCompleteText.tr,
          failedText: Intl.pullRefresh_refreshFailedText.tr,
        );
      },
      child: smartDialogInit(context, widget)),
);
~~~

~~~dart
// lib/screen/home_screen.dart:165 — current internal destination content
final content = IndexedStack(
  index: effectiveDestination.index,
  children: pages,
);
~~~

## The fix

Create a route notifier and a single Title wrapper for every named route:

~~~dart
// lib/widget/route_title.dart — target
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:list_linker/l10n/intl_keys.dart';
import 'package:list_linker/util/named_router.dart';

final ValueNotifier<String> currentRouteName = ValueNotifier(NamedRouter.root);

String titleForRoute(String route) {
  final page = switch (route) {
    NamedRouter.login => Intl.screenName_login.tr,
    NamedRouter.home || NamedRouter.fileList => Intl.screenName_home.tr,
    NamedRouter.settings => Intl.screenName_settings.tr,
    NamedRouter.donate => Intl.screenName_donate.tr,
    NamedRouter.about => Intl.screenName_about.tr,
    NamedRouter.uploadingFiles => Intl.screenName_uploadingFiles.tr,
    NamedRouter.account => Intl.settingsScreen_item_account.tr,
    NamedRouter.downloadManager => Intl.downloadManagerScreen_title.tr,
    NamedRouter.cacheManager => Intl.screenName_cacheManagement.tr,
    NamedRouter.playerSettings => Intl.screenName_playerSettings.tr,
    NamedRouter.localVideos => Intl.screenName_localVideos.tr,
    NamedRouter.localStorageBrowser => Intl.screenName_localFiles.tr,
    NamedRouter.smb || NamedRouter.smbBrowser || NamedRouter.smbScan =>
      Intl.screenName_smb.tr,
    NamedRouter.gallery => 'Gallery',
    NamedRouter.videoPlayer => 'Video',
    NamedRouter.audioPlayer => 'Audio',
    NamedRouter.pdfReader => 'PDF',
    NamedRouter.fileReader => 'File',
    NamedRouter.fileSearch => 'Search',
    NamedRouter.web => 'Web',
    _ => null,
  };
  final app = Intl.appName.tr;
  return page == null ? app : '$page · $app';
}

class RouteTitle extends StatelessWidget {
  const RouteTitle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: currentRouteName,
      builder: (context, route, child) {
        return Title(
          title: titleForRoute(route),
          color: Theme.of(context).colorScheme.surface,
          child: child!,
        );
      },
      child: child,
    );
  }
}
~~~

Update the notifier from GetMaterialApp and wrap the existing initialized child without changing its order:

~~~dart
// lib/main.dart — target fields
routingCallback: (routing) {
  final route = routing?.current;
  if (route != null && route.isNotEmpty) {
    currentRouteName.value = route;
  }
},

// inside _routerBuilder target
child: RouteTitle(
  child: smartDialogInit(context, widget),
),
~~~

HomeScreen switches several desktop/mobile destinations without a named route. Give the nearest active page its own Title so it overrides the global home title:

~~~dart
// lib/screen/home_screen.dart — target around IndexedStack
final destinationTitle = switch (effectiveDestination) {
  _HomeDestination.cloud => Intl.screenName_home.tr,
  _HomeDestination.local => Intl.screenName_localFiles.tr,
  _HomeDestination.smb => Intl.screenName_smb.tr,
  _HomeDestination.recents => Intl.screenName_recents.tr,
  _HomeDestination.favorites => Intl.screenName_favorite.tr,
  _HomeDestination.settings => Intl.screenName_settings.tr,
};
final content = Title(
  title: '$destinationTitle · ${Intl.appName.tr}',
  color: Theme.of(context).colorScheme.surface,
  child: IndexedStack(
    index: effectiveDestination.index,
    children: pages,
  ),
);
~~~

## Steps

1. Create lib/widget/route_title.dart with the notifier, route mapping, fallback, and opaque Title color shown above.
2. Import route_title.dart in main.dart.
3. Add routingCallback to GetMaterialApp and update currentRouteName only for non-empty routes.
4. Wrap smartDialogInit's existing result in RouteTitle inside _routerBuilder; preserve MediaQuery and RefreshConfiguration order.
5. In HomeScreen, compute destinationTitle from every _HomeDestination value and wrap the active IndexedStack in the nearest Title.
6. Keep GetMaterialApp.title as the native fallback; do not rely on onGenerateTitle.

## Check it

- `dart analyze` exits clean.
- `rg -n "ValueNotifier|titleForRoute|ValueListenableBuilder|Title\(" lib/widget/route_title.dart` returns the route-title implementation.
- `rg -n "routingCallback|currentRouteName|RouteTitle" lib/main.dart` returns the notifier update and wrapper.
- `rg -n "destinationTitle|Title\(|_HomeDestination.smb|_HomeDestination.settings" lib/screen/home_screen.dart` returns the internal destination mapping and nearest title.
- `rg -n "onGenerateTitle" lib/main.dart lib/widget/route_title.dart` returns no matches.

## Don't touch

- Do not change route names, route arguments, nested navigator IDs, or navigation behavior.
- Do not move SmartDialog, MediaQuery, or RefreshConfiguration outside their current builder order.
- Do not add document or file names to titles; those values can contain private user data.
- No new dependencies or unrelated localization work.

## STOP if

- GetMaterialApp routingCallback does not fire for a current named route in the installed GetX version.
- Any _HomeDestination enum value no longer matches the exhaustive switch.
- The code at any location in "Where" does not match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that browser tabs now identify the current ListLinker page without exposing file names. Open Home, SMB, Settings, Downloads, and About in web navigation and confirm each title updates.
