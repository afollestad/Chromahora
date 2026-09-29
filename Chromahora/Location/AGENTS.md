## Location

These rules cover `Chromahora/Location/` and its tests in `ChromahoraTests/Location/`.

- Round coordinates through `Place` before caching them or sending them anywhere.
- Keep `NSLocationDefaultAccuracyReduced` on in `App/Info.plist` and the watch app's `ChromahoraWatch/App/Info.plist`, so both ask for approximate location only. Rounding through `Place` discards precision anyway, and App Review expects apps to ask for no more than they use.
- Refresh `zone.tab` and `zone-links.txt` together from `/usr/share/zoneinfo`: `zone.tab` as is, and the `L` lines of `tzdata.zi` for the links. Both are public domain.
- The `.tab` and `.txt` files join the app and widget targets as bundle resources, which `ZoneTable.bundled` reads from each one's own bundle. Only `AGENTS.md` and `CLAUDE.md` are excluded.
- Verify location with `xcrun simctl privacy <udid> grant|revoke location com.afollestad.Chromahora` and `xcrun simctl location <udid> set <lat>,<lng>`, then `reset` and `clear` them. Pass a matching zone as `SIMCTL_CHILD_TZ`, since a stored fix is only reused in its own zone.
- Move a simulated location farther than `DevicePlaceProvider.moveThreshold` to see a new place, since a nearer fix keeps the stored one.
- Tests script location through `StubLocationSource` and pass `DevicePlaceProvider` an instant `sleep`, so they never wait for a fix or a timeout.
- Keep `DevicePlaceProvider` and `PlaceNames` on `AppGroup.defaults`, where the widgets read the last fix and its town, and `RecentPlaces` on `.standard`. Give all three an `InMemoryDefaults` in tests, never a real suite, which leaves a plist in the simulator on every run even after `removePersistentDomain`, and the latter two nil defaults in previews and snapshots.
- Only `MapKitPlaceSearch` imports MapKit. It keeps no state between calls, so every window shares one, and no test or snapshot reaches it: use `MockPlaceSearch` or `StubPlaceSearch`.
- Refuse a map item with no time zone (`PlaceSearchError.noTimeZone`) rather than guess one, since a guess near a border would shift every time on screen by an hour.
