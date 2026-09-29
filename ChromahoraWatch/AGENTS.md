## Watch app

These rules cover `ChromahoraWatch/`, the watchOS app the iOS app embeds, which follows the watch's own location and fetches its own sun times and forecasts.

### Build

- The app compiles the files it shares from `Chromahora/` through the exception set in `project.pbxproj` on the `Chromahora` group whose target is `ChromahoraWatch`, as `ChromahoraWidgets/AGENTS.md` describes for the widget extension: list files, never folders, and add a file whenever a shared one starts using a type it defines.
- Keep shared files compiling for watchOS, guarding a phone-only member with `#if os(iOS)` as `DebugSettings.initialPane` does. `./scripts/build.sh` builds the embedded watch app, so a watchOS error fails the iOS build too.
- Keep the target's Swift settings the app's, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` above all, since the shared files mean something else without it. Its versions come from the project level, since an embedded app must match the app's.
- Build it alone with `./scripts/build.sh --watch`, and run it with `./scripts/run.sh -w`, which takes launch arguments after `--` like the phone's and `WATCH_SIMULATOR` to pick another watch.
- Before a device build, register `com.afollestad.Chromahora.watchkitapp` with the App Group `group.com.afollestad.Chromahora`, and enable WeatherKit for it under both Capabilities and App Services. Simulator builds and CI need neither, but until WeatherKit is enabled check weather with `-DebugWeather mock`.

### Design

- Name each phase where it begins, in one column with the markers, through `WatchTimelineOverlay`, never the phone's `DayTimelineOverlay`. Two columns of labels don't fit the watch's width, and sunrise falls in the middle of golden hour, so a phase label beside it would have no room.
- Page days with the bottom bar's buttons and leave the Crown to the page on screen. Paging waits for the selected day to load, since a page from the day still shown would land on the one loading, or behind it.
- Show the day's details through the phone's `DayDetails` on `WatchDetailsPage`, a sideways swipe from the timeline, never a copy of its rows, so both stay true to `DetailTopic` and the model.
- The watch can't open web pages, so credit services in text: `WatchSourcesButton` at the foot of each day and its details always names sunrise-sunset.org and leads with the Apple Weather mark whenever the day shows weather, and its sheet opens WeatherKit's legal text in place of the phone's link. Weather sheets show the mark alone.

### Verifying

- Watch screens have no snapshot suite, since swift-snapshot-testing renders images only on iOS and tvOS. Check them with `xcrun simctl io <udid> screenshot` on `Apple Watch SE 3 (40mm)`, the narrowest, and a 46 mm or 49 mm watch.
- Set a watch's text size with a launch argument after `--`, such as `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityM` for `accessibility1`, since `xcrun simctl ui <udid> content_size` fails on watch simulators.
- Location permission belongs to the companion app's bundle ID, and an unpaired watch simulator can't show its prompt, so grant it with `xcrun simctl privacy <udid> grant location com.afollestad.Chromahora`, or use `-DebugPlace`.
