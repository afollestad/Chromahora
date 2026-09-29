## Weather

These rules cover `Chromahora/Weather/` and its tests in `ChromahoraTests/Weather/`.

- Only `WeatherKitProvider` imports WeatherKit. Its types have no public initializers, so classification and folding live in `WeatherSpell`, and hourly readings in `SkyHour`, where tests reach them.
- Every request goes through `ThrottledWeatherProvider`, since every install shares one monthly quota. Failures count toward its interval too, and one request covers the whole forecast window, never a single day.
- `ForecastCache` keeps the last request for each place and window, so switching among places within the interval asks once each. Keep its `capacity` above `RecentPlaces.capacity`, which leaves room for the device's place.
- Weather never surfaces an error or blocks the day, even with the quota spent. A failure keeps what's shown.
- Load only once `SolarDayStore.isPlaceSettled`: a lookup has finished, which a chosen place counts as at once, and none that could still move the place is out. The place before then is a stored fix or the time zone's city, and a request for it is spent on a place the device may have left.
- Check the UI with `-DebugWeather mock` and a `-DebugPlace`, or weather waits out `DevicePlaceProvider.fixTimeout` in a simulator without a location. Live data needs WeatherKit enabled for the App ID under both Capabilities and App Services; the debug drawer shows the latest request, and its Clear cache resets the throttle.
- Drive `WeatherStore` and the throttle through `StubWeatherProvider` and an injected clock, never WeatherKit.
