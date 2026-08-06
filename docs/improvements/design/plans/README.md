# Implemented plans (this session)

Selected mobile-first findings were implemented directly in the codebase (user requested).

## Delivered UX

- System nav bar list bottom inset (SafeArea bottom false + list padding)
- Brand text selection colors
- Smooth network image placeholder / error
- Asset precache on splash
- One-time slidable swipe hint on file list
- `orPlaceholder` / `isUsable` for display strings
- Haptics on bottom nav + login
- Tabular figures on video player times
- Keyboard dismiss on drag (login)
- Bottom nav reselect scrolls/pops to root
- About shows version + build number
- App-wide scrollbars via ScrollBehavior
- Opaque GestureDetector hit targets
- Friendly ErrorWidget.builder
- Login textInputAction next/done
- In-app what's new after version change

## Android

- Flutter SDK: 3.22.3 (local FVM path)
- Debug APK: `build/app/outputs/apk/debug/app-debug.apk`
- Package: `com.example.listlinker`
- Launch: `adb shell am start -n com.example.listlinker/.activity.MainActivity`
