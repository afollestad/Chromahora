# chromahora.af.codes

This branch *is* the published site. GitHub Pages serves it from the repo root, so anything committed here goes live. There is no build step: `index.html`, `privacy.html`, the sheets in `styles/`, the scripts in `scripts/` and the assets in `images/` ship verbatim. Preview with a local static server (`python3 -m http.server`) rather than opening the file directly, so relative paths resolve the way they will in production.

## Look

- The skies, section labels and accent take their colors from the app, so keep them in step with it on `main`: the phase colors from `DayPhase.color` in `Chromahora/SolarDay/SolarDay.swift`, the mauve between blue and golden hours from `SkyGradient.duskBridge`, and `--accent` from `AccentColor`'s light and dark variants. `:root` in `styles/index-common.css` names the phase colors.
- The page is a day: the light theme opens on a sunrise glow and closes on a sunset into night, and the dark theme is the app's night, opening on dusk under stars and closing on first light. The gradients that use `in oklab` follow an sRGB copy with literal colors, since a `var()` in the second declaration would defeat the fallback.
- Section labels are capsules filled with a phase's color, like the app's timeline labels.

## Theming

`styles/index-light.css` and `styles/index-dark.css` hold the color tokens and the skies, and `styles/index-common.css` holds everything theme-independent. Both theme sheets ship on every load, media-scoped to `prefers-color-scheme`, so with no override the browser follows the OS on its own, including live appearance changes, with no JavaScript involved.

`scripts/dark-mode.js` only steps in when the toggle stores an override. It flips `media` to `all` or `not all` on the sheets and on every `<picture>` source with a `data-theme`, and sets both `theme-color` metas to the override's color. Anything else that varies by theme follows that pattern: ship both variants, media-scope them, and let the script flip them. Don't swap `src` from script or hide a duplicate with `display`, since a hidden `<img>` still downloads and a script-set `src` leaves the page unthemed without JavaScript.

## Images

Encode screenshots as lossless WebP (`cwebp -lossless -z 9`), since lossy ringing shows around UI text. Each `<img>` repeats its size in `width` and `height`, and the frame's `aspect-ratio` matches, so update both when a capture's size changes.

### Screenshots

- Capture them on `main` with `./scripts/screenshots.sh -b -o <dir>` and again with `--dark`. Both runs show San Francisco on September 16 with the mock weather, so the light and dark sets match and one `alt` describes either.
- iPhone shots come from iPhone 18 Pro, halved from 1206x2622 to 603x1311: `iphone-golden-hour` is `1-golden-hour`, `iphone-blue-hour` is `2-blue-hour` and `iphone-outlook` is `3-details`. `ipad` is the iPad Pro 13-inch's `1-golden-hour`, halved to 1032x1376. Each ships as `-light` and `-dark`.
- The watch shots ship once at their native 416x496, from the light run, since the watch app is always dark. simctl can't set the watch's clock, so they show the real time of the capture.
- The captures are full screen with square corners. `.device` frames draw the bezel and round the screen, and `.phone::after` draws the Dynamic Island the captures leave room for. Each frame's geometry is a share of its screen width `--w`, measured for iPhone 18 Pro, iPad Pro 13-inch and Apple Watch Series 12 (46mm), so a capture from another device needs its own numbers.

### Widgets

The `widget-*` images are cut from the snapshot baselines in `ChromahoraTests/Snapshots/__Snapshots__/SnapshotTests+Widgets/` on `main`, which draw at 2x on a flat gray canvas:

| Image | Baseline, widget from the top |
| --- | --- |
| `widget-day` | `mediumWidgetsThisAfternoon`, 1st |
| `widget-now` | `smallWidgetsDuringGoldenHour`, 1st |
| `widget-moon` | `smallWidgetsAfterDark`, 3rd |
| `widget-sunset` | `smallWidgetsDuringGoldenHour`, 2nd |
| `widget-morning-evening` | `mediumWidgetsAfterDark`, 2nd |
| `widget-next` | `smallWidgetsThisAfternoon`, 1st |

Every baseline of a size puts its widgets in the same frames, so the corners' coverage comes from the `ThisAfternoon` one, whose yellow contrasts most with the canvas: an edge pixel there is `a * fill + (1 - a) * canvas`, solved for `a` with a flood from the box's border that stops at pure fill and so never reaches content. Each variant then takes that mask over its own flat fill, which keeps night's widgets, close to the canvas in color, the same size as the rest. Each cut keeps a pixel of clear margin on every side, so small widgets are 332x332 and medium ones 700x332, and a medium one is two small ones plus 36px, which `--widget-gap` holds at every width. Recompute the gap if the sizes change. The third widget's frame cuts a pixel taller, so `widget-moon` drops its last row, which is clear.

### Icons

- `images/app-icon-light.png` and `-dark.png` are Icon Composer renders of `Chromahora/AppIcon.icon` on `main`, with the plate, glass and corner mask already in them, scaled to 256x256: `"/Applications/Icon Composer.app/Contents/Executables/ictool" Chromahora/AppIcon.icon --export-image --output-file out.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1`, with `--rendition Dark` for the dark one.
- `favicon.png` is the light render at 96x96, in both appearances. Safari draws its own backdrop behind a favicon too dark for its tab bar, and reads icon links once at load, so a themed favicon could neither look right nor follow the toggle.
- `apple-touch-icon.png` is the light render at 180x180, flattened onto `#F9FAFB`, the middle of its plate's gradient. iOS masks it itself and fills transparent corners with black.

### Link preview

`images/og-image.png` is 1200x630 on the dark theme's opaque night (`#0d1233`), with its dusk glow and stars: the dark icon, the name in the dark title gradient and a one-line tagline on the left, and the dark `iphone-golden-hour` in its frame on the right, cut off by the bottom edge. It's rendered from a scratch page that links `styles/index-common.css` for the frame, with headless Chrome: `--headless=new --force-dark-mode --window-size=1200,630 --screenshot`. A preview can't know the reader's theme, and composites transparency unpredictably. Re-export it whenever the hero screenshot changes, and keep it a PNG, since crawler support for WebP is patchy.

## Privacy policy

- `privacy.html` is the app's privacy policy, which the App Store listing links to. Its text moved here verbatim from af.codes, which no longer hosts it, so keep this path. Change the text only with the app's data handling, and the effective date with it.
- It shares the home page's sheets and toggle: `styles/index-common.css` for the base and footer, the theme sheets for every color, and `styles/privacy.css` for its own layout. The home page's heading styles are scoped to `.hero-copy` and `.section-feature` so they don't reach it.

## Content

- Keep the App Store badge Apple's artwork, unaltered, and at least 40px tall, as its guidelines ask.
- The footer credits sunrise-sunset.org and Apple Weather, as the app does wherever their data shows.
