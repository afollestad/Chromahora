//
//  SkyLoaderTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Held requests are awaited, so a regression that never makes one would hang without the time limit.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SkyLoaderTests {
    private let places = StubPlaceProvider()
    private let days = StubSolarDayProvider()
    private let weather = StubWeatherProvider()
    private let defaults = InMemoryDefaults()
    /// GMT, so the mock days' clock times read the same wherever the tests run.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// A time in September 2026, on the 16th unless given another day.
    private func time(day: Int = 16, _ hour: Int, _ minute: Int = 0) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute)))
    }

    /// `weatherTimeout` never passes by default: it's cancelled once weather answers.
    private func makeLoader(
        sleep: @escaping @Sendable (Duration) async throws -> Void = { _ in try await Task.sleep(for: .seconds(3600)) }
    ) -> SkyLoader {
        SkyLoader(placeProvider: places, solarDays: days, weather: weather, defaults: defaults, calendar: { [calendar] in calendar }, sleep: sleep)
    }

    @Test func aDeviceFixLoadsTodayTomorrowTheirWeatherAndTheStoredTown() async throws {
        let now = try time(16, 30)
        weather.forecast = Forecast(spells: WeatherSpell.mock(for: now, calendar: calendar))
        StoredPlaceName(cell: PlaceCell(MockPlaceProvider.sanFrancisco), name: "San Francisco").write(to: defaults)

        let content = try #require(await makeLoader().content(now: now, withWeather: true))

        #expect(content.run.days.map(\.dayStart) == [try time(0), try time(day: 17, 0)])
        #expect(content.spells == weather.forecast.spells)
        #expect(weather.requestedWindows == [Forecast.window(at: now, calendar: calendar)])
        #expect(content.deviceName == "San Francisco")
    }

    /// A time zone's city is a guess the device may be far from, so it spends no request.
    @Test func aTimeZoneCityGetsNoWeather() async throws {
        places.current = Place(latitude: 37.8, longitude: -122.4, source: .timeZone("America/Los_Angeles"))

        let content = try #require(await makeLoader().content(now: try time(16, 30), withWeather: true))

        #expect(content.spells.isEmpty)
        #expect(weather.requestedPlaces.isEmpty)
    }

    @Test func aMissingTomorrowLeavesTodayAlone() async throws {
        days.holdsResponses = true
        let loader = makeLoader()
        let loading = Task { await loader.content(now: try time(16, 30), withWeather: true) }

        var requests = days.heldRequests.makeAsyncIterator()
        await requests.next()?.answer()
        await requests.next()?.fail(with: StubError())

        let content = try #require(await loading.value)
        #expect(content.run.days.count == 1)
    }

    @Test func noTodayShowsUnavailableAndRetriesSoon() async throws {
        days.error = StubError()
        let now = try time(16, 30)

        let timeline = await makeLoader().timeline(now: now, withWeather: true)

        #expect(timeline.entries.count == 1)
        #expect(timeline.entries.first.map { if case .unavailable = $0.state { true } else { false } } == true)
        #expect(timeline.reload == now.addingTimeInterval(SkyLoader.retryInterval))
    }

    /// Widgets reloaded together share one fix, one sun fetch and one forecast request.
    @Test func aLoadStillOutIsJoined() async throws {
        places.holdsResponses = true
        let loader = makeLoader()
        let now = try time(16, 30)
        let first = Task { await loader.content(now: now, withWeather: true) }
        var requests = places.heldRequests.makeAsyncIterator()
        let request = try #require(await requests.next())

        let second = Task { await loader.content(now: now, withWeather: false) }
        request.answer(MockPlaceProvider.sanFrancisco)

        #expect(await first.value != nil)
        #expect(await second.value != nil)
        #expect(places.requestedTimeZones.count == 1)
    }

    /// A load without weather can't answer a widget that shows it.
    @Test func aWeatherLoadDoesNotJoinOneWithout() async throws {
        places.holdsResponses = true
        let loader = makeLoader()
        let now = try time(16, 30)
        let first = Task { await loader.content(now: now, withWeather: false) }
        var requests = places.heldRequests.makeAsyncIterator()
        let firstRequest = try #require(await requests.next())

        let second = Task { await loader.content(now: now, withWeather: true) }
        let secondRequest = try #require(await requests.next())
        firstRequest.answer(MockPlaceProvider.sanFrancisco)
        secondRequest.answer(MockPlaceProvider.sanFrancisco)

        #expect(await first.value?.spells.isEmpty == true)
        #expect(await second.value != nil)
        #expect(weather.requestedPlaces == [MockPlaceProvider.sanFrancisco])
    }

    /// A reload the app asks for right after it has a new fix or permission loads again.
    @Test func aFinishedLoadIsNotReused() async throws {
        let loader = makeLoader()
        let now = try time(16, 30)

        _ = await loader.content(now: now, withWeather: true)
        _ = await loader.content(now: now.addingTimeInterval(1), withWeather: true)

        #expect(places.requestedTimeZones.count == 2)
    }

    /// Sun Times, Moon & Dark Sky and Morning & Evening show no weather, so they spend no quota.
    @Test func aWidgetWithoutWeatherAsksForNone() async throws {
        let content = try #require(await makeLoader().content(now: try time(16, 30), withWeather: false))

        #expect(content.spells.isEmpty)
        #expect(weather.requestedPlaces.isEmpty)
    }

    @Test func aFailedLoadIsTriedAgain() async throws {
        days.error = StubError()
        let loader = makeLoader()
        let now = try time(16, 30)
        #expect(await loader.content(now: now, withWeather: true) == nil)

        days.error = nil
        #expect(await loader.content(now: now.addingTimeInterval(60), withWeather: true) != nil)
    }

    @Test func slowWeatherLeavesTheSunTimesWithoutIt() async throws {
        weather.holdsResponses = true

        let content = try #require(await makeLoader { _ in }.content(now: try time(16, 30), withWeather: true))

        #expect(content.spells.isEmpty)
        var requests = weather.heldRequests.makeAsyncIterator()
        await requests.next()?.answer(Forecast())
    }

    @Test func aTimelineReloadsAfterTheInterval() async throws {
        let now = try time(16, 30)

        let timeline = await makeLoader().timeline(now: now, withWeather: true)

        #expect(timeline.entries.first?.date == now)
        #expect(timeline.reload == now.addingTimeInterval(SkyLoader.reloadInterval))
    }

    /// Without tomorrow, a timeline retries sooner, and never past midnight, when its entries run out.
    @Test func aMissingTomorrowReloadsSoonAndByMidnight() async throws {
        days.holdsResponses = true
        let loader = makeLoader()
        let late = try time(23, 50)
        let loading = Task { await loader.timeline(now: late, withWeather: true) }

        var requests = days.heldRequests.makeAsyncIterator()
        await requests.next()?.answer()
        await requests.next()?.fail(with: StubError())

        #expect(await loading.value.reload == (try time(day: 17, 0)))
    }

    @Test func entriesFallOnEachChangeAndWhileTheSkyShifts() throws {
        let today = SolarDay.mock(for: try time(12), calendar: calendar)
        let run = DayRun(today, then: [SolarDay.mock(for: try time(day: 17, 12), calendar: calendar)])
        let now = try time(16, 30)
        // Clouds arrive during the evening's golden hour, and rain after dark.
        func spell(_ condition: SkyCondition, _ start: Date, _ end: Date) -> WeatherSpell {
            WeatherSpell(condition: condition, interval: DateInterval(start: start, end: end), precipitationChance: 0, cloudCover: 0.5)
        }
        let spells = [
            spell(.clear, try time(12), try time(18, 40)),
            spell(.cloudy, try time(18, 40), try time(20, 50)),
            spell(.rain, try time(20, 50), try time(23))
        ]
        let content = SkyContent(place: MockPlaceProvider.sanFrancisco, deviceName: nil, run: run, spells: spells)

        let dates = SkyLoader.entryDates(for: content, from: now)

        #expect(dates.first == now)
        #expect(dates == dates.sorted())
        #expect(dates.allSatisfy { $0 >= now && $0 < run.end })
        // Golden hour starts, then the sun sets and blue hour starts, then the moon sets on the dark sky.
        for change in [try time(18, 5), try time(18, 50), try time(19, 10), try time(22, 7), try time(day: 17, 0)] {
            #expect(dates.contains(change))
        }
        // The sky shifts through golden and blue hours a quarter hour at a time, and holds
        // through daylight and night, where only the now tick's half hours get entries.
        #expect(dates.contains(try time(18, 15)))
        #expect(!dates.contains(try time(17, 15)))
        #expect(!dates.contains(try time(21, 15)))
        #expect(dates.contains(try time(17, 30)))
        // The golden hour's sky changes while it's under way, but the rain after dark changes nothing shown.
        #expect(dates.contains(try time(18, 40)))
        #expect(!dates.contains(try time(20, 50)))
        // Past the horizon, only tomorrow's changes get entries.
        #expect(dates.contains(try time(day: 17, 6, 12)))
        #expect(!dates.contains(try time(day: 17, 6, 15)))
        #expect(!dates.contains(try time(day: 17, 1)))
    }
}
