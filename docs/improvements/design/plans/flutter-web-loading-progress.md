# Fix: Flutter Web shows a blank page while the engine boots

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/flutter-web-loading-progress
- **Needs new dependency**: none

## Why

The web entry page contains only loader scripts, so users see a blank page while JavaScript, the rendering runtime, fonts, and assets load. A small progress bar tied to actual Flutter loader milestones makes the wait visible without adding weight to the initial request.

## Where

~~~html
<!-- web/index.html:35 — current loader setup -->
<script>
  // The value below is injected by flutter build, do not touch.
  var serviceWorkerVersion = null;
</script>
<!-- This script adds the flutter initialization JS code -->
<script src="flutter.js" defer></script>
~~~

~~~html
<!-- web/index.html:42 — current blank body -->
<body>
  <script>
    window.addEventListener('load', function(ev) {
      // Download main.dart.js
      _flutter.loader.loadEntrypoint({
        serviceWorker: {
          serviceWorkerVersion: serviceWorkerVersion,
        },
        onEntrypointLoaded: function(engineInitializer) {
          engineInitializer.initializeEngine().then(function(appRunner) {
            appRunner.runApp();
          });
        }
      });
    });
  </script>
</body>
~~~

## The fix

Replace the legacy inline loader with Flutter's custom bootstrap hook and visible markup:

~~~html
<!-- web/index.html — target head addition -->
<link rel="stylesheet" href="style.css">

<!-- web/index.html — target body -->
<body>
  <div class="progress-container" role="progressbar" aria-label="Loading ListLinker">
    <div class="progress-bar"></div>
  </div>
  <script src="flutter_bootstrap.js" async></script>
</body>
~~~

Create the lightweight stylesheet exactly as follows:

~~~css
/* web/style.css — target */
html,
body {
  width: 100%;
  height: 100%;
  margin: 0;
}

body {
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f8f9fb;
}

.progress-container {
  width: 120px;
  height: 6px;
  overflow: hidden;
  border-radius: 999px;
  background: #e7eaf0;
}

.progress-bar {
  width: 0;
  height: 100%;
  border-radius: inherit;
  background: #0061a4;
  transition: width 400ms ease;
}

@media (prefers-color-scheme: dark) {
  body { background: #1a1c1e; }
  .progress-container { background: #33373d; }
  .progress-bar { background: #9ecaff; }
}

@media (prefers-reduced-motion: reduce) {
  .progress-bar { transition: none; }
}
~~~

Create the bootstrap file from the article and update the ARIA value at each real milestone:

~~~javascript
// web/flutter_bootstrap.js — target
{{flutter_js}}
{{flutter_build_config}}

const progress = document.querySelector('.progress-container');
const bar = document.querySelector('.progress-bar');
const setProgress = (value) => {
  bar.style.width = `${value}%`;
  progress.setAttribute('aria-valuenow', String(value));
};

setProgress(20);

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    setProgress(50);
    const appRunner = await engineInitializer.initializeEngine();
    setProgress(80);
    await appRunner.runApp();
  },
});
~~~

## Steps

1. In web/index.html, link style.css from the head.
2. Remove the serviceWorkerVersion block, flutter.js script, and inline loadEntrypoint script.
3. Add the progress-container markup and async flutter_bootstrap.js script exactly as shown.
4. Create web/style.css with the light, dark, and reduced-motion rules above.
5. Create web/flutter_bootstrap.js with the Flutter template tokens and 20/50/80 loader milestones.
6. Keep the initial payload text-free and do not add a large image, animation, or remote font.

## Check it

- `dart analyze` exits clean.
- `rg -n "progress-container|flutter_bootstrap.js|style.css" web/index.html` returns all three target references.
- `rg -n "loadEntrypoint|serviceWorkerVersion|src=\"flutter.js\"" web/index.html` returns no matches.
- `rg -n "flutter_js|flutter_build_config|setProgress\(20\)|setProgress\(50\)|setProgress\(80\)" web/flutter_bootstrap.js` returns every bootstrap milestone.
- `rg -n "prefers-color-scheme|prefers-reduced-motion|progress-bar" web/style.css` returns the visual and accessibility rules.

## Don't touch

- Do not change Dart startup, routes, service initialization, or the native splash screens.
- Do not load remote assets from the boot page.
- Do not add a package.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- The installed Flutter tool does not support custom web/flutter_bootstrap.js template tokens.
- The code at any location in "Where" does not match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that Flutter Web now shows a small real-stage progress bar instead of a blank page. Open a production web build with cache disabled and confirm the bar appears before Flutter paints.
