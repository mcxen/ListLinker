# Design implementation order

Execute each linked plan in a fresh session. Finish its checks before starting the next one. Preserve unrelated worktree changes and locate quoted code by content because earlier plans can shift line numbers.

## Toolchain gate

The selected repository SDK is currently usable:

- `pubspec.yaml` requires Flutter `>=3.47.2`.
- `.fvm/fvm_config.json` selects `3.47.2`.
- `.fvm/flutter_sdk` points to `/Users/mcx/.fvm/versions/3.47.2`.
- `.fvm/flutter_sdk/bin/flutter --version` reports Flutter `3.47.2` and Dart `3.13.2`.

Before the first implementation session, run:

~~~text
.fvm/flutter_sdk/bin/flutter --version
.fvm/flutter_sdk/bin/flutter pub get
.fvm/flutter_sdk/bin/dart analyze
~~~

Do not continue if the SDK falls below the pubspec minimum or dependency resolution fails.

## 1. Viewport and keyboard foundations

1. [Bottom safe spacing](plans/safe-area-replacement.md) — establishes shared dynamic bottom insets.
2. [Dismiss keyboard on scroll](plans/dismiss-keyboard-on-scroll.md) — changes scroll surfaces before field behavior.
3. [Keyboard action keys](plans/text-input-action.md) — completes next, search, and submit behavior.
4. [Unfocus before modals](plans/unfocus-before-modal.md) — must precede bottom-sheet route replacement.
5. [Progressive search-result fade](plans/progressive-fade.md) — wraps the result viewport after its keyboard behavior is final.

## 2. Independent visual and data polish

6. [Complete touch targets](plans/gesture-detector-hit-area.md) — run before haptics changes the same callbacks.
7. [Precache remaining icons](plans/precache-icons.md).
8. [Fade horizontal breadcrumb edges](plans/shader-mask.md).
9. [Smooth network image loading](plans/smooth-image-loading.md).
10. [Stabilize changing digit widths](plans/tabular-figures.md) — adds typography before number expressions change.
11. [Localize displayed numbers](plans/format-numbers-for-humans.md).
12. [Localize displayed dates](plans/format-date-times.md) — initializes intl data before later main.dart changes.

## 3. Web and desktop behavior

13. [Show Flutter Web boot progress](plans/flutter-web-loading-progress.md) — replaces the legacy web loader.
14. [Add web sharing metadata](plans/flutter-web-og-image.md) — updates metadata after the loader markup is final.
15. [Disable mobile transitions on web and desktop](plans/web-page-transitions.md).
16. [Update browser tab titles per page](plans/browser-tab-title.md) — runs after other main.dart and HomeScreen edits.

## 4. Interaction and modal routes

17. [Teach swipe actions](plans/flutter-slidable-controller.md).
18. [Add semantic haptics](plans/haptic-feedback.md) — must precede shared short-sheet route changes.
19. [Make short sheets spring-driven](plans/smooth-draggable-bottom-sheets.md) — preserves focus and haptic prelude.
20. [Use adaptive large sheets](plans/adaptive-sheet-route.md) — finishes long action and copy/move routes after small sheets are separated.

## Completion gate

After every individual plan passes its own checks, run one final full analysis and inspect the combined diff. Completion requires all plan checks to remain true together; a successful check from an earlier session is not sufficient after later overlapping edits.

At minimum, verify on a physical narrow-screen phone: bottom list reachability, keyboard dismissal and action keys, swipe discovery, image loading, haptics, short-sheet dragging, and nested copy/move navigation. Verify web boot progress, sharing metadata, page titles, and transition behavior in a production web build. Verify no-transition navigation and localized contact-sheet dates on desktop, and repeat adaptive-sheet flows on both iOS and Android.
