## Sunrise-Sunset

These rules cover `Chromahora/SunriseSunset/` and its tests in `ChromahoraTests/SunriseSunset/`.

- Build API dates and month keys from a Gregorian calendar in the store calendar's time zone, never the device calendar, which may be Buddhist or Japanese.
- Map each crossing by its fixed from → into phases and let `SolarDay.make` order them by time, never by field name. `tz` windowing puts evening crossings before morning ones and carries blue hour past midnight.
- Bump `SolarDayCache.formatVersion` whenever `SolarDayRecord`'s stored shape changes, so `prune` clears the old files.
- Keep the client's session ephemeral. The disk cache is the only cache, and a `URLCache` copy would answer the debug drawer's cold reload.
- Tests never touch the network: drive the provider through `StubSunriseSunsetFetcher`, and add real responses to `SunriseSunsetFixtures` fetched with `curl`, since Cloudflare rejects some clients' user agents.
