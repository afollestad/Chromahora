## Snapshot Tests

These rules cover `ChromahoraTests/Snapshots/`: `SnapshotTests` and its `+Topic` files, `assertScreenSnapshot()`, and the baselines under `__Snapshots__/`. `assertScreenSnapshot()` and `scripts/snapshots.sh` document their own mechanisms, so keep a rule here only when the code that would break it isn't the code that explains it.

### Running

- Use `./scripts/snapshots.sh`, never a raw `xcodebuild` run. It pins the device and `en_US`, forwards the record mode past the simulator's separate environment, and fails when a filter matches nothing, which otherwise reads as a pass.
- Quote focused identifiers, since Swift Testing's end in `()`: `./scripts/snapshots.sh verify 'ChromahoraTests/SnapshotTests/afternoon()'`.
- A passing `verify` doesn't prove a baseline is current. `0.99` precision allows 1% of pixels, and a label or pill covers far less, so after an intended change `record` and open the new PNGs.
- Failed comparisons write the new image to `.build/snapshot-failures/`. Compare it with the baseline to see what moved.
- Baselines hold only on iPhone 18 Pro, in `en_US`, on the current simulator runtime. When an Xcode or runtime update fails them with no code change, re-record and review the diffs.

### Writing

- Build dates with `time(day:_:_:)`, never absolute timestamps. It uses local components on a day without a daylight saving change, so labels match in every time zone.
- Snapshot the timeline through `timeline(now:)`, not `ContentView`, whose `TimelineView` reads the real clock. `ContentView` suits the placeholders when given a fixed `selectedDate`.
- The status bar, Dynamic Island and home indicator draw outside the app and never appear. Check them with simulator screenshots.
- Group tests into `SnapshotTests+Topic.swift` files by screen. Moving a test between files moves its baseline under `__Snapshots__/`, so move or re-record the PNG with it.
