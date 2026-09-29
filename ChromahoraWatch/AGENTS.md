## Watch app

These rules cover `ChromahoraWatch/`, the watchOS app the iOS app embeds, which follows the watch's own location and fetches its own sun times and forecasts.

- The app compiles the files it shares from `Chromahora/` through the exception set in `project.pbxproj` on the `Chromahora` group whose target is `ChromahoraWatch`, as `ChromahoraWidgets/AGENTS.md` describes for the widget extension: list files, never folders, and add a file whenever a shared one starts using a type it defines.
- Keep shared files compiling for watchOS, guarding a phone-only member with `#if os(iOS)` as `DebugSettings.initialPane` does. `./scripts/build.sh` builds the embedded watch app, so a watchOS error fails the iOS build too.
- Keep the target's Swift settings the app's, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` above all, since the shared files mean something else without it. Its versions come from the project level, since an embedded app must match the app's.
- Build it alone with `./scripts/build.sh --watch`, and run it with `./scripts/run.sh -w`, which takes launch arguments after `--` like the phone's and `WATCH_SIMULATOR` to pick another watch.
- Before a device build, register `com.afollestad.Chromahora.watchkitapp` with the App Group `group.com.afollestad.Chromahora`, and enable WeatherKit for it under both Capabilities and App Services. Simulator builds and CI need neither, but until WeatherKit is enabled check weather with `-DebugWeather mock`.
