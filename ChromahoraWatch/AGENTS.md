## Watch app

These rules cover `ChromahoraWatch/`, the watchOS app the iOS app embeds, which follows the watch's own location and fetches its own sun times and forecasts.

### Build

- The app compiles the files it shares from `Chromahora/` through the exception set in `project.pbxproj` on the `Chromahora` group whose target is `ChromahoraWatch`, as `ChromahoraWidgets/AGENTS.md` describes for the widget extension: list files, never folders, and add a file whenever a shared one starts using a type it defines.
- Keep shared files compiling for watchOS, guarding a phone-only member with `#if os(iOS)` as `DebugSettings.initialPane` does. `./scripts/build.sh` builds the embedded watch app, so a watchOS error fails the iOS build too.
- Keep the target's Swift settings the app's, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` above all, since the shared files mean something else without it. Its versions come from the project level, since an embedded app must match the app's.
- Build it alone with `./scripts/build.sh --watch`, and run it with `./scripts/run.sh -w`, which takes launch arguments after `--` like the phone's and `WATCH_SIMULATOR` to pick another watch.
- Before a device build, register `com.afollestad.Chromahora.watchkitapp` with the App Group `group.com.afollestad.Chromahora`, and enable WeatherKit for it under both Capabilities and App Services. Simulator builds and CI need neither, but until WeatherKit is enabled check weather with `-DebugWeather mock`.

### Design

- The Crown moves through each day's cards, a vertical page `TabView` of `WatchSummaryCard`, the morning and evening `WatchEndCard`s and `WatchDetailsPage`, and a sideways swipe pages days. `WatchDayPager` holds three pages, recentering without animation on the day a swipe lands on and keeping the card on screen, and pages only from the selected day once loaded, since a page from the day still shown would land on the one loading, or behind it.
- Show Previous Day and Next Day in the bottom bar only while VoiceOver runs. Without them VoiceOver has no sure way between days, and for everyone else they'd cover the bottom of every card.
- Keep the top of every card dark, since the system draws the clock in white whatever's behind it. The summary's sky climbs from night at the top, and the end cards hold their sky in a `WatchSkyPanel` under the header.
- Name each phase where it begins, in one column with the markers, through `WatchSkyPanel`, never the phone's `DayTimelineOverlay`. Two columns of labels don't fit the watch's width, and sunrise falls in the middle of golden hour, so a phase label beside it would have no room.
- Show the day's details through the phone's `DayDetails` on `WatchDetailsPage`, the last card, never a copy of its rows, so both stay true to `DetailTopic` and the model.
- The watch can't open web pages, so credit services in text: `WatchSourcesButton` at the foot of `WatchDetailsPage`, the foot of the day, always names sunrise-sunset.org and leads with the Apple Weather mark whenever the day shows weather, and its sheet opens WeatherKit's legal text in place of the phone's link. An end card whose panel shows weather carries the mark in its header, and weather sheets show the mark alone.

### Verifying

- Watch screens have no snapshot suite, since swift-snapshot-testing renders images only on iOS and tvOS. Check them with `xcrun simctl io <udid> screenshot` on `Apple Watch SE 3 (40mm)`, the narrowest, and a 46 mm or 49 mm watch.
- Move through a day's cards with a vertical `axe drag` and between days with a sideways one, since `axe` can't turn the Crown.
- Set a watch's text size with a launch argument after `--`, such as `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityM` for `accessibility1`, since `xcrun simctl ui <udid> content_size` fails on watch simulators.
- Location permission belongs to the companion app's bundle ID, and an unpaired watch simulator can't show its prompt, so grant it with `xcrun simctl privacy <udid> grant location com.afollestad.Chromahora`, or use `-DebugPlace`.
