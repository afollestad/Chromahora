## Location

These rules cover `Chromahora/Location/` and its tests in `ChromahoraTests/Location/`.

- Round coordinates through `Place` before caching them or sending them anywhere.
- Refresh `zone.tab` and `zone-links.txt` together from `/usr/share/zoneinfo`: `zone.tab` as is, and the `L` lines of `tzdata.zi` for the links. Both are public domain.
- The `.tab` and `.txt` files join the app target as bundle resources, which `ZoneTable.bundled` reads. Only `AGENTS.md` and `CLAUDE.md` are excluded.
