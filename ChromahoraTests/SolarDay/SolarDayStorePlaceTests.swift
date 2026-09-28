//
//  SolarDayStorePlaceTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Choosing a place in another zone, returning to the device's, and lookups that answer too late
/// for either. Held requests are awaited, so a regression that never makes one would hang without
/// the time limit.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SolarDayStorePlaceTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Mid-afternoon on Monday, September 21, 2026, in GMT, when it's late evening in Tokyo.
    private let monday = Date(timeIntervalSince1970: 1_790_000_000)
    /// Monday evening in GMT, when it's already Tuesday morning in Tokyo.
    private var mondayEvening: Date { monday.addingTimeInterval(6 * 60 * 60) }

    private let provider = StubSolarDayProvider()
    private let places = StubPlaceProvider()
    private let kyoto = Place(latitude: 35.0, longitude: 135.8, source: .chosen(name: "Kyoto", timeZone: "Asia/Tokyo"))
    private let reykjavik = Place(latitude: 64.1, longitude: -21.9, source: .chosen(name: "Reykjavík", timeZone: "Atlantic/Reykjavik"))

    private func makeStore(selectedDate: Date? = nil) -> SolarDayStore {
        SolarDayStore(provider: provider, placeProvider: places, calendar: calendar, selectedDate: selectedDate ?? monday)
    }

    private func zone(_ identifier: String) throws -> TimeZone {
        try #require(TimeZone(identifier: identifier))
    }

    private func calendar(in identifier: String) throws -> Calendar {
        var calendar = calendar
        calendar.timeZone = try zone(identifier)
        return calendar
    }

    // MARK: Choosing

    @Test func choosingAPlaceWindowsDaysToItsZone() async throws {
        let tokyo = try zone("Asia/Tokyo")
        let store = makeStore()
        await store.loadSelectedDay()

        store.choose(kyoto, now: monday)

        #expect(store.place == kyoto)
        #expect(store.isPlaceChosen)
        #expect(store.calendar.timeZone == tokyo)
        #expect(store.deviceTimeZone == .gmt)
        #expect(store.state.isLoading)
        #expect(store.state.day != nil)

        await store.loadSelectedDay()

        #expect(provider.requestedPlaces.last == kyoto)
        #expect(store.state.loadedDay?.calendar.timeZone == tokyo)
    }

    /// Weather follows the place of the day on screen, so a new place's forecast arriving before its
    /// day can't mark the last place's.
    @Test func theShownPlaceWaitsForItsDay() async {
        let store = makeStore()
        await store.loadSelectedDay()
        #expect(store.shownPlace == MockPlaceProvider.sanFrancisco)

        store.choose(kyoto, now: monday)
        #expect(store.shownPlace == MockPlaceProvider.sanFrancisco)

        await store.loadSelectedDay()
        #expect(store.shownPlace == kyoto)
    }

    /// It's Monday evening in GMT and already Tuesday in Kyoto, so today there is Tuesday.
    @Test func todayStaysTodayThere() throws {
        let store = makeStore(selectedDate: mondayEvening)

        store.choose(kyoto, now: mondayEvening)

        #expect(store.selectedDate == mondayEvening)
        #expect(try calendar(in: "Asia/Tokyo").dateComponents([.month, .day], from: store.selectedDayStart) == DateComponents(month: 9, day: 22))
    }

    /// Wednesday evening in GMT is Thursday morning in Kyoto, but the day being looked at is Wednesday.
    @Test func anotherDayKeepsItsDate() throws {
        let wednesdayEvening = mondayEvening.addingTimeInterval(2 * 24 * 60 * 60)
        let store = makeStore(selectedDate: wednesdayEvening)

        store.choose(kyoto, now: mondayEvening)

        let components = try calendar(in: "Asia/Tokyo").dateComponents([.month, .day, .hour], from: store.selectedDate)
        #expect(components == DateComponents(month: 9, day: 23, hour: 12))
    }

    /// Weather waits for a finished lookup, and a chosen place needs none.
    @Test func aChosenPlaceIsFoundAtOnce() async {
        let store = makeStore()

        store.choose(kyoto, now: monday)
        #expect(store.locateCount == 1)
        await store.locate()

        #expect(places.requestedTimeZones.isEmpty)
        #expect(store.locatedCount == 1)
        #expect(store.place == kyoto)
    }

    @Test func choosingTheSamePlaceChangesNothing() {
        let store = makeStore()
        store.choose(kyoto, now: monday)
        let key = store.loadKey
        let locateCount = store.locateCount

        store.choose(kyoto, now: mondayEvening)
        store.choose(Place(latitude: 1, longitude: 1, source: .device), now: monday)

        #expect(store.loadKey == key)
        #expect(store.locateCount == locateCount)
        #expect(store.selectedDate == monday)
    }

    @Test func returningToAPlaceLoadsItFromMemory() async {
        let store = makeStore()

        store.choose(kyoto, now: monday)
        await store.loadSelectedDay()
        store.choose(reykjavik, now: monday)
        await store.loadSelectedDay()
        store.choose(kyoto, now: monday)
        await store.loadSelectedDay()

        #expect(provider.requestedPlaces == [kyoto, reykjavik])
        #expect(store.state.loadedDay != nil)
    }

    /// A zone with no city leaves nothing to show until a place is chosen.
    @Test func choosingAPlaceFixesAMissingOne() async {
        places.lastKnown = nil
        places.error = PlaceError.unavailable(timeZone: "GMT")
        let store = makeStore()
        await store.locate()
        #expect(store.state.failure != nil)

        store.choose(kyoto, now: monday)
        #expect(store.state.isLoading)
        await store.loadSelectedDay()

        #expect(store.state.loadedDay != nil)
    }

    // MARK: Returning to the device

    @Test func returningToTheDeviceAsksWhereItIs() async {
        let store = makeStore()
        await store.loadSelectedDay()
        store.choose(kyoto, now: monday)

        store.useCurrentLocation(now: monday)

        #expect(!store.isPlaceChosen)
        #expect(store.calendar.timeZone == .gmt)
        #expect(store.place == MockPlaceProvider.sanFrancisco)
        #expect(store.locateCount == 2)
        #expect(store.state.day != nil)

        places.current = Place(latitude: 41.85, longitude: -87.65, source: .device)
        await store.locate()

        #expect(places.requestedTimeZones == [.gmt])
        #expect(store.place == places.current)
    }

    /// With no device place to go on, the chosen place's day mustn't stay under the device's title.
    @Test func returningWithoutADevicePlaceClearsTheScreen() async {
        places.lastKnown = nil
        let store = makeStore()
        store.choose(kyoto, now: monday)
        await store.loadSelectedDay()
        #expect(store.state.loadedDay != nil)

        store.useCurrentLocation(now: monday)

        #expect(store.place == nil)
        #expect(store.state.isLoading)
        #expect(store.state.day == nil)
    }

    @Test func returningWhileAtTheDeviceChangesNothing() {
        let store = makeStore()
        let key = store.loadKey

        store.useCurrentLocation(now: monday)

        #expect(store.loadKey == key)
        #expect(store.locateCount == 0)
    }

    /// Travel while a place is chosen leaves the choice alone, and returning finds the device in its new zone.
    @Test func aZoneChangeWhileChosenKeepsThePlace() async throws {
        let tokyo = try zone("Asia/Tokyo")
        let losAngeles = try zone("America/Los_Angeles")
        let store = makeStore()
        store.choose(kyoto, now: monday)
        let locateCount = store.locateCount

        store.changeTimeZone(to: losAngeles)

        #expect(store.place == kyoto)
        #expect(store.calendar.timeZone == tokyo)
        #expect(store.deviceTimeZone == losAngeles)
        #expect(store.locateCount == locateCount)

        store.useCurrentLocation(now: monday)
        await store.locate()

        #expect(store.calendar.timeZone == losAngeles)
        #expect(places.requestedTimeZones == [losAngeles])
    }

    /// Moving into the chosen place's zone still counts as the device's move, for when the choice is let go.
    @Test func movingIntoTheChosenZoneIsNoted() throws {
        let tokyo = try zone("Asia/Tokyo")
        let store = makeStore()
        store.choose(kyoto, now: monday)

        store.changeTimeZone(to: tokyo)
        store.useCurrentLocation(now: monday)

        #expect(store.calendar.timeZone == tokyo)
    }

    // MARK: Late lookups

    @Test func aLookupAnsweringAfterAChoiceIsDropped() async throws {
        places.holdsResponses = true
        var requests = places.heldRequests.makeAsyncIterator()
        let store = makeStore()

        let locating = Task { await store.locate() }
        let request = try #require(await requests.next())
        store.choose(kyoto, now: monday)
        request.answer(Place(latitude: 41.85, longitude: -87.65, source: .device))
        await locating.value

        #expect(store.place == kyoto)
        #expect(store.locatedCount == 0)
    }

    /// A lookup cancelled as the zone changes mustn't land its old zone's fix under the new one.
    @Test func aCancelledLookupsAnswerIsDropped() async throws {
        places.holdsResponses = true
        var requests = places.heldRequests.makeAsyncIterator()
        let store = makeStore()

        let locating = Task { await store.locate() }
        let request = try #require(await requests.next())
        locating.cancel()
        request.answer(Place(latitude: 41.85, longitude: -87.65, source: .device))
        await locating.value

        #expect(store.place == MockPlaceProvider.sanFrancisco)
        #expect(store.locatedCount == 0)
    }
}
