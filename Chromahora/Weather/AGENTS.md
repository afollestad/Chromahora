## Weather

These rules cover `Chromahora/Weather/` and its tests in `ChromahoraTests/Weather/`.

- Only `WeatherKitProvider` imports WeatherKit. Its types have no public initializers, so classification and folding live in `WeatherSpell`, where tests reach them.
- Every request goes through `ThrottledWeatherProvider`, since every install shares one monthly quota. Failures count toward its interval too, and one request covers the whole forecast window, never a single day.
- Weather never surfaces an error or blocks the day, even with the quota spent. A failure keeps what's shown.
- Load only after a location lookup finishes (`SolarDayStore.locatedCount`). The place before it is a stored fix or the time zone's city, and a request for it is spent on a place the device may have left.
- Check the UI with `-DebugWeather mock` and a `-DebugPlace`, or weather waits out `DevicePlaceProvider.fixTimeout` in a simulator without a location. Live data needs WeatherKit enabled for the App ID under both Capabilities and App Services; the debug drawer shows the last request, and its Clear cache resets the throttle.
- Drive `WeatherStore` and the throttle through `StubWeatherProvider` and an injected clock, never WeatherKit.
