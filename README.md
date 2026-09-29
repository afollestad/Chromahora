# Chromahora

Chromahora is a native iOS day planner for photographers: blue hour, golden hour, weather, UV, moon phase and dark skies.

Its home screen widgets show the next golden or blue hour, the next sunrise or sunset, the moon and tonight's dark sky, and the whole day's light at a glance.

On Apple Watch, the day's sky scrolls under the Digital Crown a day at a time, with its details a swipe away, and complications on the watch face show when the next golden or blue hour starts, or while one is under way, when it ends.

Sun and moon times come from [sunrise-sunset.org](https://sunrise-sunset.org), weather from [Apple WeatherKit](https://developer.apple.com/weatherkit/), and place search and town names from Apple Maps. Live weather needs WeatherKit enabled for the App ID, under both Capabilities and App Services.

## Development

```sh
./scripts/setup.sh             # Install SwiftLint, xcsift and AXe, and a lint pre-commit hook
./scripts/build.sh             # Build for the iOS Simulator, with the watch app it embeds (--watch builds the watch app alone)
./scripts/run.sh -b            # Build, install, and launch in the simulator (omit -b to relaunch the last build; -w for the watch app; pass launch arguments after --)
./scripts/test.sh              # Run unit and snapshot tests
./scripts/snapshots.sh verify  # Compare snapshots against their baselines (record to update them)
./scripts/lint.sh              # Run SwiftLint
```

## License

Chromahora is licensed under the [GNU General Public License v3.0](LICENSE.md).
