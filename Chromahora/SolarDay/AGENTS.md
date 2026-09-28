## Solar Day

These rules cover `Chromahora/SolarDay/` and its tests in `ChromahoraTests/SolarDay/`.

- A day is its phase at midnight plus each phase change. High latitudes skip phases and carry them past midnight, so never assume a phase, a sunrise or a sunset exists.
- Build days from outside data through `SolarDay.make`, which sorts, folds and checks the changes. The unchecked memberwise init is for fixed data like `MockScenario` and tests, and a test runs every scenario through `make`.
- Key anything the store holds per day by its calendar's time zone as well as place and date, since `changeTimeZone(to:)` swaps the zone while the app runs.
- `selectDay(offsetBy:from:)` must set `state` before it returns for a day `loadAdjacentDays()` already holds. `DayPager` pushes in a page that follows `state` right after, so it would open on the day it replaces.
- Add a unit test whenever `SolarDay` or `SolarDayStore` gains behavior. Drive store tests through `StubSolarDayProvider` so response order is explicit, never timed.
