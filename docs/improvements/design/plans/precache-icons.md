# Fix: Less common image assets still decode after their first screen appears

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

> Line numbers in "Where" are baseline anchors. Earlier completed plans may shift them; locate the quoted block by content and stop only if its behavior or structure changed.

- **Link**: https://flutterpro.design/details/md/precache-icons
- **Needs new dependency**: none

## Why

The splash screen waits for common assets, but roughly half of the declared PNG assets are omitted. File-type icons, external-player icons, donation/settings icons, and the fast-forward indicator can therefore paint a frame late the first time their screen opens.

## Where

~~~dart
// lib/screen/splash_screen.dart:85 — current
const assets = <String>[
  Images.logo,
  Images.iconArrowRight,
  Images.fileTypeFolder,
  Images.fileTypeImage,
  Images.fileTypeVideo,
  Images.fileTypeAudio,
  Images.fileTypePdf,
  Images.fileTypeUnknow,
  Images.loginScreenServerUrl,
  Images.loginScreenAccount,
  Images.loginScreenPassword,
  Images.settingsScreenDownload,
  Images.settingsScreenCacheManager,
  Images.settingsScreenPlayer,
  Images.settingsScreenAccount,
  Images.settingsScreenAbout,
  Images.accountIcon,
];
await Future.wait(
  assets.map((path) => precacheImage(AssetImage(path), ctx)),
);
~~~

~~~dart
// lib/generated/images.dart:1 — current asset registry
class Images {
  static const String accountIcon = 'assets/images/account_icon.png';
  static const String accountIconChoosed = 'assets/images/account_icon_choosed.png';
  // file type, player, login, logo, and settings constants continue below
}
~~~

## The fix

Keep first-screen assets awaited and load every remaining declared asset in the background. Use two explicit lists so startup is not delayed by icons that are not visible immediately:

~~~dart
// lib/screen/splash_screen.dart — target
const criticalAssets = <String>[
  Images.logo,
  Images.iconArrowRight,
  Images.fileTypeFolder,
  Images.fileTypeImage,
  Images.fileTypeVideo,
  Images.fileTypeAudio,
  Images.fileTypePdf,
  Images.fileTypeUnknow,
  Images.loginScreenServerUrl,
  Images.loginScreenAccount,
  Images.loginScreenPassword,
  Images.settingsScreenDownload,
  Images.settingsScreenCacheManager,
  Images.settingsScreenPlayer,
  Images.settingsScreenAccount,
  Images.settingsScreenAbout,
  Images.accountIcon,
];

const deferredAssets = <String>[
  Images.accountIconChoosed,
  Images.fileTypeApk,
  Images.fileTypeCode,
  Images.fileTypeDocment,
  Images.fileTypeExcel,
  Images.fileTypeMd,
  Images.fileTypePpt,
  Images.fileTypeWord,
  Images.fileTypeZip,
  Images.icInfuse,
  Images.icLauncher,
  Images.icNplayer,
  Images.icVlc,
  Images.iconFfwd,
  Images.settingsScreenDonate,
  Images.settingsScreenPrivacyPolicy,
];

await Future.wait(
  criticalAssets.map((path) => precacheImage(AssetImage(path), ctx)),
);
unawaited(
  Future.wait(
    deferredAssets.map((path) => precacheImage(AssetImage(path), ctx)),
  ),
);
~~~

Import dart:async for unawaited. There are no SVG assets, so the flutter_svg branch from the article is not needed.

## Steps

1. Add import dart:async to lib/screen/splash_screen.dart.
2. Rename the existing assets constant to criticalAssets without changing its entries.
3. Add deferredAssets with every missing Images constant shown above.
4. Await the critical list and call unawaited on the deferred Future.wait exactly as shown.
5. Compare the union of both lists to lib/generated/images.dart and ensure each Images constant appears exactly once.

## Check it

- dart analyze exits clean.
- rg -n "criticalAssets|deferredAssets|unawaited" lib/screen/splash_screen.dart returns the two lists and background call.
- A line-by-line comparison against lib/generated/images.dart confirms every static Images constant is present once across the two lists.
- rg -n "flutter_svg" pubspec.yaml lib/screen/splash_screen.dart returns no new dependency or import.

## Don't touch

- Do not regenerate or hand-edit lib/generated/images.dart.
- Do not await deferredAssets.
- Do not add SVG support while the asset registry contains only PNG files.
- Do not change splash navigation, database initialization, or authentication timing.
- No new dependencies.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- `flutter --version` cannot run or reports a version below the pubspec minimum `3.47.2`; repair the repository's SDK selection in a separate environment task before editing UI code.
- The asset registry gains a non-PNG asset while implementing the plan.
- Any listed constant no longer exists.
- The code at the location in "Where" doesn't match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that every bundled icon is now decoded either before the first screen or quietly in the background. Open Settings, a folder containing varied file types, and the player selector after a cold start to see the result.
