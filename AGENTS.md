# AGENTS.md

Guidance for AI agents working in this repo. `README.md` says what the app is.

## About this file

- Keep only durable, non-obvious rules: things an agent cannot derive from the code, git history, or `README.md` and would otherwise get wrong.
- Do not record file inventories, task history, in-progress work, or personal tooling preferences. Those live in each agent's global config.
- One rule per bullet, in the imperative, at most two sentences. Add the reason inline when it isn't obvious.
- Sections are fixed and stay in the order below. A section holds at most ten rules; when it outgrows that, move the detail to a file under `docs/agents/` and leave a one-line pointer here.
- Rules that apply to a single directory go in an `AGENTS.md` inside that directory, not here.
- Before editing files in a folder, read its `AGENTS.md` if it has one. Some agents load only the root file.
- Whenever you create an `AGENTS.md`, create a `CLAUDE.md` symlink beside it (`ln -s AGENTS.md CLAUDE.md`), so every agent loads it.
- List both files in their target's `membershipExceptions` in `project.pbxproj`, or the synchronized group copies them into the bundle, where same-named files collide. Xcode drops an exception whose path no longer exists when it next saves the project, so recheck after moving either.
- Keep this file under 120 lines. Delete rules that stop being true rather than hedging them.

## Build and test

- Xcode 27 project with iOS 27 and watchOS 27 deployment targets. Use iOS 26+ APIs such as Liquid Glass, scroll edge effects, and `navigationSubtitle` freely, except in files the watch app shares, which watchOS must compile.
- Source folders are synchronized groups. New files under `Chromahora/`, `ChromahoraTests/`, `ChromahoraWidgets/` or `ChromahoraWatch/` join their targets automatically, so never edit `project.pbxproj` to add files; its only membership edits are the `AGENTS.md` exclusions above, each target's `Info.plist`, which `INFOPLIST_FILE` merges into the generated plist for keys with no `INFOPLIST_KEY_` setting, and the files the widget extension and the watch app share from `Chromahora/`, which `ChromahoraWidgets/AGENTS.md` and `ChromahoraWatch/AGENTS.md` cover.
- First-time setup: `./scripts/setup.sh` installs `swiftlint`, `xcsift` and `axe` and a pre-commit hook that lints.
- Build, run, test, lint and snapshot through `scripts/`, not raw `xcodebuild`, `simctl launch` or `swiftlint`. They pin the simulator, test locale and DerivedData path that results and baselines depend on, and sign builds so WeatherKit accepts the app.
- Build: `./scripts/build.sh`, which builds the watch app the app embeds too. Run in the simulator: `./scripts/run.sh -b` builds first, while bare `run.sh` relaunches the last build (set `SIMULATOR` to pick another device), and `-w` runs the watch app instead.
- Tests use Swift Testing: `./scripts/test.sh`, or pass identifiers such as `ChromahoraTests/SolarDayTests`. It runs snapshot suites on their own devices, `SnapshotTests` on iPhone 18 Pro and `WideSnapshotTests` on iPad mini (A17 Pro), and everything else on `SIMULATOR`'s.
- Snapshots: `./scripts/snapshots.sh verify`, or `record` to rewrite baselines and then verify them. It runs each suite on its own device, and `ChromahoraTests/Snapshots/AGENTS.md` covers both.
- Lint: `./scripts/lint.sh` from the repo root. SwiftLint runs in strict mode and Swift warnings are errors, so both fail on any warning.
- Keep `-parallel-testing-enabled NO` and `-collect-test-diagnostics never` in the test scripts. Parallel testing runs on clones that shut the original simulator down, and failure diagnostics take a sysdiagnose that stalls every failing run for about ten minutes.
- Scripts build into `.build/xcode` so agent builds don't touch the shared DerivedData, and pipe through `xcsift` when installed; read its TOON `status` and `summary`.

## Verifying UI

- Every visible change is checked in the simulator, not just compiled: launch it with `./scripts/run.sh -b` and capture with `xcrun simctl io <udid> screenshot`.
- Every visible change also runs `./scripts/snapshots.sh verify`. When the change is intended, `record` the affected baselines and look at the new images.
- Reach other states with debug launch arguments after `--`, e.g. `./scripts/run.sh -b -- -DebugNow 2026-09-16T03:00:00 -DebugProviderMode hang`. `DebugSettings` documents each one; give `-DebugPlace` hemisphere letters (`33.9S,151.2E`), since the argument domain drops a value starting with `-`.
- `simctl` cannot tap or drag, so use `axe touch --down --up --delay 0.1`, `axe drag` and `axe describe-ui` with `--udid`, which reach the simulator without the host's cursor; never post host mouse events, which take over the user's. `axe tap` doesn't activate this app's controls and `axe swipe` often leaves its scroll views in place, so tap and scroll with those instead.
- If `axe touch` stops activating controls while `axe drag` still scrolls, the simulator's input is stuck: shut it down with `xcrun simctl shutdown <udid>`, and `run.sh` boots it again.
- To open a popover without a tap, flip its state from a `.task` after a short delay, because presentations on the first frame don't render; to reach the page beside the timeline, launch with `-DebugPane details`.
- Restore every temporary patch before finishing. Keep a backup copy and confirm with `git diff`.

## Design rules

- `SolarDay` is the single contract for a day's sun and moon data, which `SolarDayStore` loads through a `SolarDayProvider` for a `Place` from a `PlaceProvider`. `ChromahoraApp` and `ChromahoraWatchApp` build the real ones once, and `SkyLoader.live` the widgets'; the mocks serve previews, tests, the debug drawer and the widgets' placeholder.
- Keep weather out of `SolarDay`, since forecasts change and fail while sun times don't. `WeatherStore` loads a `Forecast` of `WeatherSpell`s and `SkyHour`s through a `WeatherProvider`, and a failure only leaves the timeline without them.
- Floating chrome is Liquid Glass: labels are glass capsules, and the title, which names the place and opens the location sheet, and the calendar button are glass toolbar items. The top edge, and the bottom under `SourcesButton`, use the soft scroll edge effect, which blurs labels and lines under the bars so they don't run through the clock or the button; the hard style would paint a dark band.
- A regular-width window with room for a 390pt timeline beside it (iPad, an opened foldable, a Pro Max in landscape) floats the glass `DayPanel` on the trailing side in place of the calendar button. Size class and width alone decide, with no control to hide it.
- Without the panel, a sideways swipe pages from the timeline to `DayDetailsPage` over `DayPager`'s copy of the sky, with `PageDots` under `SourcesButton`. The panel lists the same `DayDetails` under its calendar, with no pager.
- Popovers and the day panel keep the default Liquid Glass like the rest of the floating chrome, not a material background, so give them primary text and underlined links; a bright sky through the glass washes out gray and tinted text. Cap their content at `accessibility1`, since at their width larger text breaks to a word a line.
- Keep `AccentColor` a golden-hour orange, never gold: in dark mode the popovers' glass over daylight turns mustard and swallows a yellower accent. The calendar fills today's circle with it under white text, so hold both variants to 3:1 against white and 4.5:1 on the location sheet's rows.
- Format dates on screen in the zone the store windows days to, through `SolarDay+Text`, or `Date.dayTitle(in:)` and `shortDayTitle(in:)` in the store calendar's zone, never `.dateTime` or `formatted(date:time:)`, which read the device's zone. A place chosen in another zone keeps its own clock.
- Hide decorative shapes from accessibility. Every control needs a label, and the calendar button also exposes the selected day as its value.
- Keep the sunrise-sunset.org link and `AppleWeatherCredit` in `SourcesButton`'s popover, and `AppleWeatherCredit` in the weather popover and under the day panel's weather, though `DayDetailsPage` leaves it to the button right below; both services' terms require them. The button always names sunrise-sunset.org, whose terms want the credit visible, and leads with the Apple Weather mark whenever the timeline shows weather, since App Review looks for the mark wherever weather shows.

## Code conventions

- Group files by theme in folders under `Chromahora/`, mirrored in `ChromahoraTests/`. Put a new file in the theme it serves, or start a theme when none fits.
- Keep each view file to one screen or overlay.
- Every view has a `#Preview`. Use `@Previewable @State` for bindings.
- Doc comments explain why a constant has its value, not what the code does.
- Read state that changes while scrolling, like the sky behind the chrome or the scheme it picks, only in the small view or modifier that shows it, passed down as a binding. Read in `DayScreen`'s or `DayPager`'s body, it rebuilds every page and the details on each change.
- Present popover content with `popoverContent()`, never `presentationCompactAdaptation(.popover)` alone, since iOS 27 can center it in a container longer than its glass.
- Unit tests cover the model and snapshots cover screens.
- Write test files into a `TemporaryDirectory` held by the suite, which removes it after each test, since the simulator doesn't empty a test host's `tmp` between runs. Await any task that outlives the call under test, such as a prefetch, or it writes the directory back after removal.
