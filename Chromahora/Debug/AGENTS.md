## Debug

These rules cover `Chromahora/Debug/`.

- Wrap every file here in `#if DEBUG`. The only debug code outside this folder is the `#if DEBUG` hooks in `ChromahoraApp`, `ContentView`, `ChromahoraWatchApp`, `WatchContentView`, `SolarDayStore` and `DevicePlaceProvider`, so Release never names a `Debug*` type.
- Don't unit-test debug tooling: it never ships and breaks visibly on first use, so tests only add upkeep. Production code it calls, like `SolarDayStore.reload()`, is still tested.
- Never persist a setting. Launch arguments seed them from the argument domain alone, so an override can't outlive the session that set it.
- Every setting has a launch argument, so scripts and agents reach it without a tap: add one alongside any new control.
