## Widgets

These rules cover `Chromahora/Widgets/`, which holds what the widgets show and how it loads, and its tests in `ChromahoraTests/Widgets/`. The app compiles these files too, so tests reach them; `ChromahoraWidgets/AGENTS.md` covers the extension that shows them.

- Widgets follow the device, never a chosen place, which the app keeps no longer than a launch. `SkyLoader` places the device through `DevicePlaceProvider` and `WidgetLocationSource`, falling back to the last fix the app or a widget took, then to the zone's city.
- Load only through `SkyLoader.live`, which every kind of widget shares, so widgets reloaded together share one fix, one sun fetch and one forecast request.
- Ask for weather only through `WidgetWeather`, which answers from the app's or its own recent forecast and otherwise throttles its own requests apart from the app's. Ask only for a device fix, and never let weather hold up the sun times past `SkyLoader.weatherTimeout`.
- Put `WidgetCredit` on every widget: sunrise-sunset.org always, led by the Apple Weather mark whenever the widget shows a weather glyph. Link the credits only in medium widgets and larger, which WidgetKit lets hold links, and the app passes them on to Safari in `ContentView`'s `onOpenURL`.
- Sit every widget on `skyWidgetBackground(for:)`, which paints the sky at the entry's moment and gives text the scheme that reads over it. Never set a scheme or text colors of your own: a tinted or clear Home Screen, and StandBy, take the sky away and color the text themselves.
- Word times through `DayRun`'s or `SolarDay+Text`'s helpers, in the run's zone, never `.dateTime` or `Text(date, style: .time)`, and countdowns through `WidgetCountdown`, whose reference style names one rounded unit, as in "in 8 hours" or "in 35 minutes".
- Keep timelines sparse through `SkyLoader.entryDates(in:from:)`: an entry for every change a widget shows, and steps only while the sky's color shifts. WidgetKit caps an extension's memory, and every entry costs some.
- Previews and snapshots paint the sky themselves, with `.background(SkyBackground(entry:))` under `skyWidgetBackground(for:)`, since `containerBackground` draws only inside WidgetKit.
