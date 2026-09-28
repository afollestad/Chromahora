# Chromahora

Chromahora is an iOS app designed to show photographers when blue hour and golden hour are in a given day.

Sun and moon times come from [sunrise-sunset.org](https://sunrise-sunset.org), and weather from [Apple WeatherKit](https://developer.apple.com/weatherkit/). Live weather needs WeatherKit enabled for the App ID, under both Capabilities and App Services.

## Development

```sh
./scripts/setup.sh             # Install SwiftLint, xcsift and AXe, and a lint pre-commit hook
./scripts/build.sh             # Build for the iOS Simulator
./scripts/run.sh -b            # Build, install, and launch in the simulator (omit -b to relaunch the last build; pass launch arguments after --)
./scripts/test.sh              # Run unit and snapshot tests
./scripts/snapshots.sh verify  # Compare snapshots against their baselines (record to update them)
./scripts/lint.sh              # Run SwiftLint
```

## License

Chromahora is licensed under the [GNU General Public License v3.0](LICENSE.md).
