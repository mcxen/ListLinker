# Fix: Shared ListLinker links have no preview card

> Follow the steps in order. Run every check. If anything in "STOP if"
> happens, stop and report instead of improvising.

- **Link**: https://flutterpro.design/details/md/flutter-web-og-image
- **Needs new dependency**: none

## Why

The web entry page has a generic Flutter description and no Open Graph or X metadata. Shared links therefore appear as a bare URL instead of a recognizable ListLinker card.

## Where

~~~html
<!-- web/index.html:19 — current -->
<meta charset="UTF-8">
<meta content="IE=Edge" http-equiv="X-UA-Compatible">
<meta name="description" content="A new Flutter project.">
~~~

~~~html
<!-- web/index.html:32 — current -->
<title>alist</title>
~~~

## The fix

Use the public repository as the currently verified canonical URL and host the preview image at a known absolute raw-content URL:

~~~html
<!-- web/index.html — target metadata -->
<meta name="description" content="ListLinker is a cross-platform file manager for OpenList and Alist servers.">

<!-- Open Graph -->
<meta property="og:title" content="ListLinker – OpenList and Alist file manager">
<meta property="og:description" content="Browse, manage, and play files from OpenList and Alist across mobile, desktop, and web.">
<meta property="og:image" content="https://raw.githubusercontent.com/mcxen/ListLinker/main/web/og-image.png">
<meta property="og:url" content="https://github.com/mcxen/ListLinker">
<meta property="og:type" content="website">

<!-- X / Twitter -->
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="ListLinker – OpenList and Alist file manager">
<meta name="twitter:description" content="Browse, manage, and play files from OpenList and Alist across mobile, desktop, and web.">
<meta name="twitter:image" content="https://raw.githubusercontent.com/mcxen/ListLinker/main/web/og-image.png">

<title>ListLinker</title>
~~~

Create web/og-image.png at exactly 1200×630. Use a #F8F9FB background, center the existing ListLinker app icon at 224×224, place “ListLinker” below it in #1A1C1E, and place “OpenList and Alist file manager” as the smaller subtitle. Keep all content inside a 96px safe margin so social platforms can crop safely.

## Steps

1. Replace the generic description and `alist` title in web/index.html with the target ListLinker values.
2. Add every Open Graph and X tag shown above inside the head.
3. Create web/og-image.png at 1200×630 using the exact composition above and the existing web app icon as source artwork.
4. Do not use a relative URL for og:image or twitter:image.
5. If the project later receives a verified production web origin, update og:url and both absolute image URLs together in a separate deployment change.

## Check it

- `rg -n "og:title|og:description|og:image|og:url|og:type|twitter:card|twitter:title|twitter:description|twitter:image" web/index.html` returns every target tag.
- `rg -n "A new Flutter project|<title>alist</title>" web/index.html` returns no matches.
- `file web/og-image.png` reports a PNG image.
- `sips -g pixelWidth -g pixelHeight web/og-image.png` reports 1200 and 630.
- Both image meta tags start with `https://` and end with `/web/og-image.png`.

## Don't touch

- Do not change the runtime router, browser-title behavior, manifest, launcher icons, or favicon.
- Do not invent a production deployment domain that is not present in the repository.
- No new dependencies or remote design assets.
- No refactors, renames, or cleanups beyond the fix.

## STOP if

- The default branch is not `main`, because the absolute raw image URL would be wrong.
- The existing app icon cannot be reused under the repository's current license.
- The code at any location in "Where" does not match the quoted excerpt.
- The fix seems to require touching something in "Don't touch".
- A check fails twice.

## When you're done

Tell the developer that shared ListLinker links now carry a title, description, and large preview image. Validate the final public URL with an Open Graph debugger after the image is reachable from the default branch.
