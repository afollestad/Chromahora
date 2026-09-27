## Location

These rules cover `Chromahora/Location/` and its tests in `ChromahoraTests/Location/`.

- Round coordinates through `Place` before caching them or sending them anywhere.
- Refresh `zone.tab` and `zone-links.txt` together from `/usr/share/zoneinfo`: `zone.tab` as is, and the `L` lines of `tzdata.zi` for the links. Both are public domain.
- The `.tab` and `.txt` files join the app target as bundle resources, which `ZoneTable.bundled` reads. Only `AGENTS.md` and `CLAUDE.md` are excluded.
- Verify location with `xcrun simctl privacy <udid> grant|revoke location com.afollestad.Chromahora` and `xcrun simctl location <udid> set <lat>,<lng>`, then `reset` and `clear` them. Pass a matching zone as `SIMCTL_CHILD_TZ`, since a stored fix is only reused in its own zone.
- Tests script location through `StubLocationSource` and pass `DevicePlaceProvider` an instant `sleep`, so they never wait for a fix or a timeout.
