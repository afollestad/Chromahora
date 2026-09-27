# AGENTS.md

Guidance for AI agents working in this repo. `README.md` says what the app is.

## About this file

- Keep only durable, non-obvious rules: things an agent cannot derive from the code, git history, or `README.md` and would otherwise get wrong.
- Do not record file inventories, task history, in-progress work, or personal tooling preferences. Those live in each agent's global config.
- One rule per bullet, in the imperative, at most two sentences. Add the reason inline when it isn't obvious.
- Sections are fixed and stay in the order below. A section holds at most ten rules; when it outgrows that, move the detail to a file under `docs/agents/` and leave a one-line pointer here.
- Rules that apply to a single directory go in an `AGENTS.md` inside that directory, not here.
- Keep this file under 120 lines. Delete rules that stop being true rather than hedging them.

## Build and test

- Xcode 27 project with an iOS 27 deployment target. Use iOS 26+ APIs such as Liquid Glass, scroll edge effects, and `navigationSubtitle` freely.
- Source folders are synchronized groups. New files under `Chromahora/` or `ChromahoraTests/` join their targets automatically; never edit `project.pbxproj` to add files.
- First-time setup: `./scripts/setup.sh` installs `swiftlint` and `xcsift` and a pre-commit hook that lints.
- Build, run, test, lint and snapshot through `scripts/`, not raw `xcodebuild`, `simctl launch` or `swiftlint`. They pin the simulator, test locale and DerivedData path that results and baselines depend on.
- Build: `./scripts/build.sh`. Run in the simulator: `./scripts/run.sh -b` builds first, while bare `run.sh` relaunches the last build (set `SIMULATOR` to pick another device).
- Tests use Swift Testing: `./scripts/test.sh`, or pass identifiers such as `ChromahoraTests/SolarDayTests`. It includes the snapshot suite except on another `SIMULATOR`.
- Snapshots: `./scripts/snapshots.sh verify`, or `record` to rewrite baselines and then verify them. `ChromahoraTests/Snapshots/AGENTS.md` covers the suite.
- Lint: `./scripts/lint.sh` from the repo root. SwiftLint runs in strict mode and Swift warnings are errors, so both fail on any warning.
- Keep `-parallel-testing-enabled NO` and `-collect-test-diagnostics never` in the test scripts. Parallel testing runs on clones that shut the original simulator down, and failure diagnostics take a sysdiagnose that stalls every failing run for about ten minutes.
- Scripts build into `.build/xcode` so agent builds don't touch the shared DerivedData, and pipe through `xcsift` when installed; read its TOON `status` and `summary`.

## Verifying UI

- Every visible change is checked in the simulator, not just compiled: launch it with `./scripts/run.sh -b` and capture with `xcrun simctl io <udid> screenshot`.
- Every visible change also runs `./scripts/snapshots.sh verify`. When the change is intended, `record` the affected baselines and look at the new images.
- `simctl` cannot scroll or tap. To inspect another part of the timeline, temporarily override `now` in `ContentView`, or pass it a `selectedDate` from `ChromahoraApp`; to open a popover, flip its state from a `.task` after a short delay, because presentations on the first frame don't render.
- To see the loading or failed placeholders, temporarily hand `ContentView` a provider that never answers or always throws.
- Restore every temporary patch before finishing. Keep a backup copy and confirm with `git diff`.
- Check anything in the navigation bar over three backdrops: around 3 AM (night), mid afternoon (daylight), and with `now` near 11:35 AM, which puts the title over the sunrise blend where the bar's scheme flips.
- Check timeline label changes with `SIMULATOR="iPhone 17e"` at `xcrun simctl ui <udid> content_size accessibility-medium`, then reset it to `large`. The 17e is the narrowest iPhone simulator at 390pt and AX1 is the labels' size cap, so labels collide there first.
- Check edge-hugging changes in landscape too: call `requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))` on the window scene from a temporary `.task`, and capture with `--mask=black` to see the Dynamic Island.

## Design rules

- Vertical position is proportional to time of day. Never compress or stretch phases to make them more visible; zoom (`pointsPerHour`) and scrolling are the only tools.
- `SolarDay` is the single contract for a day's data, which `SolarDayStore` loads through a `SolarDayProvider`. `MockSolarDayProvider` is a placeholder, and `ChromahoraApp` is the one place to swap in a real provider.
- All positions come from `SolarDay.fraction(of:)`. Never hard-code hours or minutes in views.
- The sky gradient interpolates in perceptual color space, holds color across night and daylight, peaks at the midpoint of blue and golden hours, and crosses a mauve stop between them. Blue and golden are near-complementary and blend to mud otherwise.
- Floating chrome is Liquid Glass: labels are glass capsules, and the title and calendar button are glass toolbar items. No scroll edge effects, since the soft style blurs hours of timeline and the hard style paints a dark band.
- The title's glass is tinted with `SkyGradient.color(at:in:)` behind its center, and the navigation bar's color scheme follows that color's luminance, not the phase, since phases blend into each other.
- The timeline draws edge to edge, so its content sees zero safe-area insets. Inset labels by the per-edge `safeAreaInsets` that `DayTimeline` measures outside `ignoresSafeArea`, never by a fixed padding alone.
- Keep `labelSpacing` in `DayTimelineOverlay` larger than the glass container's merge distance so stacked capsules never fuse.
- Hide decorative shapes from accessibility. Every control needs a label, and the calendar button also exposes the selected day as its value.

## Code conventions

- Views live in `Chromahora/Views/` and models in `Chromahora/Model/`. Keep each view file to one screen or overlay.
- Every view has a `#Preview`. Use `@Previewable @State` for bindings.
- Doc comments explain why a constant has its value, not what the code does.
- Unit tests cover the model and snapshots cover screens. Add a unit test whenever `SolarDay` or `SolarDayStore` gains behavior, and drive store tests through `StubSolarDayProvider` so response order is explicit, never timed.
