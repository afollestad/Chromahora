## Snapshot Tests

These rules cover `ChromahoraTests/Snapshots/`: `SnapshotTests` and its `+Topic` files, `assertScreenSnapshot()`, and the baselines under `__Snapshots__/`. `assertScreenSnapshot()` and `scripts/snapshots.sh` document their own mechanisms, so keep a rule here only when the code that would break it isn't the code that explains it.

### Running

- Use `./scripts/snapshots.sh`, never a raw `xcodebuild` run. It pins the device and `en_US`, forwards the record mode past the simulator's separate environment, and fails when a filter matches nothing, which otherwise reads as a pass.
- Quote focused identifiers, since Swift Testing's end in `()`: `./scripts/snapshots.sh verify 'ChromahoraTests/SnapshotTests/afternoon()'`.
- A passing `verify` doesn't prove a baseline is current. `0.99` precision allows 1% of pixels, and a label or pill covers far less, so after an intended change `record` and open the new PNGs.
- Failed comparisons write the new image to `.build/snapshot-failures/`. Compare it with the baseline to see what moved.
- `record` rewrites every baseline it runs, with encoder noise even when nothing moved, so pass the identifiers of the ones meant to change.
- A test with no baseline yet makes `xcsift` report an unrelated test as "did not complete (possible crash)". The raw log has the real outcome; create new baselines with `record`.
- Baselines hold only on their suite's device, full screen in portrait, in `en_US`, on the current simulator runtime: `SnapshotTests` on iPhone 18 Pro, and `WideSnapshotTests` on iPad mini (A17 Pro). When an Xcode or runtime update fails them with no code change, re-record and review the diffs.

### Writing

- Build dates with `time(month:day:_:_:)`, never absolute timestamps. It uses local components, so labels match in every time zone, as long as the day has no daylight saving change anywhere: September 16, June 21, December 10 and December 21 are safe.
- Snapshot screens through `DayScreen`, with `timeline(now:)`, `timeline(_:now:)` or `screen(_:selectedDate:now:)`, never `ContentView`, whose `TimelineView` reads the real clock and whose store loads.
- The status bar, Dynamic Island and home indicator draw outside the app and never appear. Check them with simulator screenshots.
- Put screens with the day panel in `WideSnapshotTests+Topic.swift`, dated in June 2026 with `june(day:_:_:)`. The panel's calendar marks the real today, and `time` fixes the year, so a later month would fail once it arrives.
- Group tests into `SnapshotTests+Topic.swift` files by screen. Moving a test between files moves its baseline under `__Snapshots__/`, so move or re-record the PNG with it.
- Give each test a name no other test in its suite uses. The test bundle copies every baseline into one folder, so two `+Topic` files' same-named baselines fail the build; `SnapshotDevice.baselineName` keeps the two suites apart.
