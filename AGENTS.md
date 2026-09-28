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

- Xcode 27 project with an iOS 27 deployment target. Use iOS 26+ APIs such as Liquid Glass, scroll edge effects, and `navigationSubtitle` freely.
- Source folders are synchronized groups. New files under `Chromahora/` or `ChromahoraTests/` join their targets automatically, so never edit `project.pbxproj` to add files; its only membership edits are the `AGENTS.md` exclusions above.
- First-time setup: `./scripts/setup.sh` installs `swiftlint` and `xcsift` and a pre-commit hook that lints.
- Build, run, test, lint and snapshot through `scripts/`, not raw `xcodebuild`, `simctl launch` or `swiftlint`. They pin the simulator, test locale and DerivedData path that results and baselines depend on, and sign builds so WeatherKit accepts the app.
- Build: `./scripts/build.sh`. Run in the simulator: `./scripts/run.sh -b` builds first, while bare `run.sh` relaunches the last build (set `SIMULATOR` to pick another device).
- Tests use Swift Testing: `./scripts/test.sh`, or pass identifiers such as `ChromahoraTests/SolarDayTests`. It includes the snapshot suite except on another `SIMULATOR`.
- Snapshots: `./scripts/snapshots.sh verify`, or `record` to rewrite baselines and then verify them. `ChromahoraTests/Snapshots/AGENTS.md` covers the suite.
- Lint: `./scripts/lint.sh` from the repo root. SwiftLint runs in strict mode and Swift warnings are errors, so both fail on any warning.
- Keep `-parallel-testing-enabled NO` and `-collect-test-diagnostics never` in the test scripts. Parallel testing runs on clones that shut the original simulator down, and failure diagnostics take a sysdiagnose that stalls every failing run for about ten minutes.
- Scripts build into `.build/xcode` so agent builds don't touch the shared DerivedData, and pipe through `xcsift` when installed; read its TOON `status` and `summary`.

## Verifying UI

- Every visible change is checked in the simulator, not just compiled: launch it with `./scripts/run.sh -b` and capture with `xcrun simctl io <udid> screenshot`.
- Every visible change also runs `./scripts/snapshots.sh verify`. When the change is intended, `record` the affected baselines and look at the new images.
- Reach other states with debug launch arguments after `--`, e.g. `./scripts/run.sh -b -- -DebugNow 2026-09-16T03:00:00 -DebugProviderMode hang`. `DebugSettings` documents each one; give `-DebugPlace` hemisphere letters (`33.9S,151.2E`), since the argument domain drops a value starting with `-`.
- `simctl` cannot scroll or tap. To open a popover, flip its state from a `.task` after a short delay, because presentations on the first frame don't render.
- Restore every temporary patch before finishing. Keep a backup copy and confirm with `git diff`.

## Design rules

- `SolarDay` is the single contract for a day's sun data, which `SolarDayStore` loads through a `SolarDayProvider` for a `Place` from a `PlaceProvider`. `ChromahoraApp` builds the real ones once; the mocks serve previews, tests and the debug drawer.
- Keep weather out of `SolarDay`, since forecasts change and fail while sun times don't. `WeatherStore` loads `WeatherSpell`s through a `WeatherProvider`, and a failure only leaves the timeline without them.
- Floating chrome is Liquid Glass: labels are glass capsules, and the title and calendar button are glass toolbar items. The top edge, and the bottom under `SourcesButton`, use the soft scroll edge effect, which blurs labels and lines under the bars so they don't run through the clock or the button; the hard style would paint a dark band.
- Popovers keep the default Liquid Glass like the rest of the floating chrome, not a material background, so give them primary text and underlined links; a bright sky through the glass washes out gray and tinted text. Cap their content at `accessibility1`, since a popover can't outgrow the screen and truncates larger text to a word a line.
- Hide decorative shapes from accessibility. Every control needs a label, and the calendar button also exposes the selected day as its value.
- Keep the sunrise-sunset.org link and `AppleWeatherCredit` in `SourcesButton`'s popover, and `AppleWeatherCredit` in the weather popover; both services' terms require them. The button reads as the Apple Weather mark whenever the timeline shows weather, since App Review looks for the mark wherever weather shows.

## Code conventions

- Group files by theme in folders under `Chromahora/`, mirrored in `ChromahoraTests/`. Put a new file in the theme it serves, or start a theme when none fits.
- Keep each view file to one screen or overlay.
- Every view has a `#Preview`. Use `@Previewable @State` for bindings.
- Doc comments explain why a constant has its value, not what the code does.
- Unit tests cover the model and snapshots cover screens.
