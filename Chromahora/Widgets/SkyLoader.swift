//
//  SkyLoader.swift
//  Chromahora
//

import Foundation

/// Loads what the widgets show: where the device is, today and tomorrow there, and the sky over
/// them. WidgetKit reloads each kind of widget on its own, often several at once, so a load
/// still out is joined, keeping them to one fix and one forecast request between them. A
/// finished one is never reused, since a reload the app asks for may come right after it has a
/// new fix, forecast or permission; loading again costs little once CoreLocation has a recent
/// fix and the forecast is fresh.
final class SkyLoader {
    /// How often a widget reloads, which paces its fix and forecast, since its sun times hold
    /// through tomorrow. A little past `WidgetWeather.interval`, so a reload that comes on time
    /// finds the throttle open rather than a moment short of it, which would leave the forecast
    /// another interval older.
    static let reloadInterval = WidgetWeather.interval + 10 * 60
    /// How soon a widget whose sun times couldn't load tries again.
    static let retryInterval: TimeInterval = 30 * 60
    /// How long weather may hold up the sun times, which show without it. WidgetKit gives a reload
    /// only seconds. The request goes on after, and reaches the next reload if the extension lives
    /// to store it; if not, the attempt it recorded holds the widgets' next request off for
    /// `WidgetWeather.interval`, as a failure's does.
    static let weatherTimeout: Duration = .seconds(8)
    /// How far ahead the sky's color gets entries of its own. Past it, only the day's changes
    /// get one, since a reload comes long before, and each entry costs the widget memory.
    static let colorHorizon: TimeInterval = 8 * 60 * 60
    /// How often the sky's color moves on while it shifts, which WidgetKit can't animate. A
    /// quarter hour is a small step even across a short blue hour.
    static let colorStep: TimeInterval = 15 * 60
    /// How often the day strip's now tick moves within `colorHorizon`, which only an entry
    /// moves: a half hour is a few points of the strip.
    static let tickStep: TimeInterval = 30 * 60

    private let placeProvider: any PlaceProvider
    private let solarDays: any SolarDayProvider
    /// Nil where no widget shows weather, like the watch's complications, which have no room for
    /// Apple Weather's credit, so none of them can spend the quota.
    private let weather: (any WeatherProvider)?
    private let defaults: UserDefaults
    /// The device's calendar, read at each load, since its zone can change between them.
    private let calendar: () -> Calendar
    /// Waits out `weatherTimeout`, and tests replace it so they never wait for real.
    private let sleep: @Sendable (Duration) async throws -> Void
    /// The load still out, and whether it asks for weather, which later calls join.
    private var loading: (withWeather: Bool, task: Task<SkyContent?, Never>)?

    init(
        placeProvider: any PlaceProvider,
        solarDays: any SolarDayProvider,
        weather: (any WeatherProvider)?,
        defaults: UserDefaults = AppGroup.defaults,
        calendar: @escaping () -> Calendar = { .current },
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.placeProvider = placeProvider
        self.solarDays = solarDays
        self.weather = weather
        self.defaults = defaults
        self.calendar = calendar
        self.sleep = sleep
    }

    /// A timeline's entries from `now`, and when to reload it: sooner when today's sun times
    /// couldn't load, whose widget meanwhile says so, or tomorrow's, and never past the run's
    /// end, after which its entries have nothing to show. Weather comes only `withWeather`, for
    /// a widget that shows it, so the others spend none of the quota.
    func timeline(now: Date, withWeather: Bool) async -> (entries: [SkyEntry], reload: Date) {
        guard let content = await content(now: now, withWeather: withWeather) else {
            return ([SkyEntry(date: now, state: .unavailable)], now.addingTimeInterval(Self.retryInterval))
        }
        let entries = Self.entryDates(for: content, from: now).map { SkyEntry(date: $0, state: .loaded(content)) }
        let interval = content.run.reachesTomorrow ? Self.reloadInterval : Self.retryInterval
        return (entries, min(now.addingTimeInterval(interval), content.run.end))
    }

    /// What the widgets show at `now`, from the load still out, unless it lacks weather that
    /// `withWeather` asks for, or else a new one. Nil when today's sun times can't load.
    func content(now: Date, withWeather: Bool) async -> SkyContent? {
        if let loading, loading.withWeather || !withWeather {
            return await loading.task.value
        }
        let task = Task { await load(now: now, withWeather: withWeather) }
        loading = (withWeather, task)
        defer {
            if loading?.task == task {
                loading = nil
            }
        }
        return await task.value
    }

    /// When a timeline's entries fall from `now`: at every change a widget shows through the
    /// end of the run, including a golden or blue hour's sky changing while it's under way, and
    /// within `colorHorizon`, every `tickStep` and every `colorStep` while the sky's color shifts.
    /// It shifts only around golden and blue hours, so night and day, which hold their color,
    /// need no more than the tick's entries.
    static func entryDates(for content: SkyContent, from now: Date) -> [Date] {
        let run = content.run
        let magicHours = run.segments.filter(\.phase.isMagicHour)
        let skyChanges = content.spells.flatMap { [$0.interval.start, $0.interval.end] }
            .filter { date in magicHours.contains { $0.interval.start < date && date < $0.interval.end } }
        let changes = run.segments.map(\.interval.start)
            + run.days.flatMap(\.events).map(\.date)
            + run.days.flatMap { $0.darkSky ?? [] }.flatMap { [$0.start, $0.end] }
            + run.days.map(\.dayStart)
            + skyChanges
        var dates = Set(changes.filter { $0 > now && $0 < run.end })
        dates.insert(now)

        let horizon = min(now.addingTimeInterval(colorHorizon), run.end)
        var step = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / colorStep).rounded(.down) * colorStep + colorStep)
        var color = SkyBackground.color(at: now, in: run)
        while step < horizon {
            let next = SkyBackground.color(at: step, in: run)
            if next != color || step.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: tickStep) == 0 {
                dates.insert(step)
                color = next
            }
            step = step.addingTimeInterval(colorStep)
        }
        return dates.sorted()
    }

    /// Places the device, then loads today and tomorrow there beside the forecast, and the town
    /// the app last named for the place. A missing tomorrow leaves the run a day short, while a
    /// missing today leaves nothing to show.
    private func load(now: Date, withWeather: Bool) async -> SkyContent? {
        let calendar = calendar()
        guard let place = try? await placeProvider.currentPlace(in: calendar.timeZone) else {
            return nil
        }
        async let spells = withWeather ? weatherSpells(at: place, now: now, calendar: calendar) : []
        guard let today = try? await solarDays.solarDay(for: now, at: place, calendar: calendar) else {
            return nil
        }
        let tomorrow = try? await solarDays.solarDay(for: today.dayEnd, at: place, calendar: calendar)
        let run = DayRun(today, then: tomorrow.map { [$0] } ?? [])
        return SkyContent(
            place: place,
            deviceName: StoredPlaceName.name(for: place, in: defaults),
            run: run,
            spells: await spells.filter { $0.interval.end > run.start && $0.interval.start < run.end }
        )
    }

    /// The forecast's spells, or none if it doesn't answer within `weatherTimeout`. Only for the
    /// device's own fix, as the app does once a lookup settles: a time zone's city is a guess
    /// the device may be far from, and a request for it would spend the quota for nothing.
    private func weatherSpells(at place: Place, now: Date, calendar: Calendar) async -> [WeatherSpell] {
        guard let weather, case .device = place.source, let window = Forecast.window(at: now, calendar: calendar) else {
            return []
        }
        let (answers, answer) = AsyncStream<[WeatherSpell]>.makeStream()
        // The request isn't awaited past the deadline, so it runs in a task of its own, which
        // goes on to store its answer for the next reload after this one gives up on it.
        Task {
            answer.yield((try? await weather.forecast(from: window.start, to: window.end, at: place))?.spells ?? [])
        }
        let deadline = Task { [sleep] in
            try? await sleep(Self.weatherTimeout)
            answer.yield([])
        }
        defer {
            deadline.cancel()
            answer.finish()
        }
        for await spells in answers {
            return spells
        }
        return []
    }
}
