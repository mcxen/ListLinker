# Design findings (selected for implementation)

Selected for mobile/Android-first UX work on ListLinker. Web-only items deferred.

**1. Show what's new after an update**

after an update, users open the app and nothing tells them what's new. The bug you fixed and the feature they asked for go unnoticed. Show them as a list on first open after an update, and the user who reported that bug or asked for that feature knows you listened.

**Link:** https://flutterpro.design/details/md/in-app-changelog

**2. Don't let the system navigation bar cover the bottom of scrollable lists**

the last item of scrollable lists gets obscured by the system navigation bar. Leave space as tall as that bar at the end of the list so the last item has a breathing room against the bar.

**Link:** https://flutterpro.design/details/md/safe-area-replacement

**3. Match text selection to your app's colors**

`MaterialApp` applies default tinted colors for text selection in inputs. Match them to your brand colors instead.

**Link:** https://flutterpro.design/details/md/selection-color

**4. Load network images smoothly**

images in Flutter load with no transition, no placeholder and no failure state. They just pop in. Make it calmer: Show a plain grey box until each picture is ready and fade it in. If fails show a subtle broken image icon, never a technical message.

**Link:** https://flutterpro.design/details/md/smooth-image-loading

**5. Preload images and icons so they don't pop in**

Flutter loads images and icons into memory when a widget first asks for them, and decoding takes time. So they are painted a few frames late. Precache them during splash view so they are ready when painted.

**Link:** https://flutterpro.design/details/md/precache-icons

**6. Teach users swiping an item right and left for actions**

users who don't have muscle memory to look for actions behind items by swiping left and right, never find out those actions exist. Programmatically open and close those actions for the first time user opens that page to teach them the gesture.

**Link:** https://flutterpro.design/details/md/flutter-slidable-controller

**7. Never show "null" on screen**

when a string field comes back `null` or empty from the API and gets displayed directly, the user sees the word "null" or a blank spot on screen. A bad experience, and something they should never see. Instead, gate those values to show "-" or "N/A".

**Link:** https://flutterpro.design/details/md/never-show-null

**9. Add haptic feedback to key moments**

the app feels flat when taps and results happen in silence. A subtle haptic vibration on a tab switch, a successful submit or an error makes the app feel responsive in the hand.

**Link:** https://flutterpro.design/details/md/haptic-feedback

**10. Use tabular figures for changing numbers**

digits have different widths in most fonts, so a timer or counter jumps around as it changes. Tabular figures make every digit the same width: numbers stay still and line up.

**Link:** https://flutterpro.design/details/md/tabular-figures

**12. Dismiss the keyboard when the user scrolls**

the user finishes typing and scrolls to see the rest, but the keyboard stays covering half the screen. Scrolling means they're done with the field, so close it for them.

**Link:** https://flutterpro.design/details/md/dismiss-keyboard-on-scroll

**13. Scroll to top when the current bottom nav item is tapped again**

tapping the bottom nav bar item you're already on should scroll that page to the top. It's muscle memory for native app users, so they'll expect it from your apps too.

**Link:** https://flutterpro.design/details/md/bottom-nav-reselect

**14. Show the app version in settings**

when a user reports a bug, the first question is which version they're on, and the app has no place to answer it.

**Link:** https://flutterpro.design/details/md/show-app-version

**16. Show scrollbars on vertical scrollables**

a scrollbar shows the user where they are in the list and how much is left.

**Link:** https://flutterpro.design/details/md/scrollbars

**17. Make the whole GestureDetector area tappable**

by default `GestureDetector` only takes taps on what its child paints, so the padding and the gaps between an icon and a text do nothing. The user taps the row and misses. The whole box should take the tap.

**Link:** https://flutterpro.design/details/md/gesture-detector-hit-area

**19. Show a friendly view when a widget breaks**

when a widget fails to build, users see an empty grey box in release. Show a friendly "Something went wrong" in the app's own colors instead.

**Link:** https://flutterpro.design/details/md/friendly-error-view

**20. Give every text field the right keyboard action**

users should be able to fill a form and submit it with the keyboard's action key alone: it moves them to the next field, and on the last one, submits. No tapping each field by hand.

**Link:** https://flutterpro.design/details/md/text-input-action
