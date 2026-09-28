//
//  SolarDayStoreTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Held requests are awaited, so a regression that never makes one would hang without the time limit.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SolarDayStoreTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Mid-afternoon, so a selected time is distinguishable from the start of its day.
    private let monday = Date(timeIntervalSince1970: 1_790_000_000)
    private var tuesday: Date { monday.addingTimeInterval(24 * 60 * 60) }
    private var sunday: Date { monday.addingTimeInterval(-24 * 60 * 60) }
    private var wednesday: Date { monday.addingTimeInterval(2 * 24 * 60 * 60) }

    private let provider = StubSolarDayProvider()
    private let places = StubPlaceProvider()
    private let chicago = Place(latitude: 41.85, longitude: -87.65, source: .device)

    private func makeStore() -> SolarDayStore {
        SolarDayStore(provider: provider, placeProvider: places, calendar: calendar, selectedDate: monday)
    }

    private func dayStart(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    @Test func loadsTheSelectedDayByItsStart() async {
        let store = makeStore()
        #expect(store.state.isLoading)
        #expect(store.state.day == nil)

        await store.loadSelectedDay()

        #expect(provider.requestedDates == [dayStart(monday)])
        #expect(store.state.loadedDay?.dayStart == dayStart(monday))
    }

    @Test func revisitedDaysComeFromTheCache() async {
        let store = makeStore()
        await store.loadSelectedDay()
        store.selectedDate = tuesday
        await store.loadSelectedDay()

        store.selectedDate = monday.addingTimeInterval(2 * 60 * 60)
        await store.loadSelectedDay()

        #expect(provider.requestedDates == [dayStart(monday), dayStart(tuesday)])
        #expect(store.state.loadedDay?.dayStart == dayStart(monday))
    }

    @Test func failureShowsAndRetryRecovers() async {
        let store = makeStore()
        provider.error = StubError()
        await store.loadSelectedDay()
        #expect(store.state.failure is StubError)

        provider.error = nil
        await store.loadSelectedDay()

        #expect(store.state.loadedDay?.dayStart == dayStart(monday))
    }

    /// Try Again reloads through the view's task, which restarts because the load key changes.
    @Test func reloadAfterAFailureAsksAgain() async {
        let store = makeStore()
        provider.error = StubError()
        await store.loadSelectedDay()
        let failedKey = store.loadKey

        store.reload()
        #expect(store.loadKey != failedKey)
        #expect(store.state.isLoading)
        #expect(store.state.day == nil)

        provider.error = nil
        await store.loadSelectedDay()

        #expect(provider.requestedDates == [dayStart(monday), dayStart(monday)])
        #expect(store.state.loadedDay?.dayStart == dayStart(monday))
    }

    @Test func reloadKeepsTheDayOnScreen() async {
        let store = makeStore()
        await store.loadSelectedDay()

        store.reload()

        #expect(store.state.isLoading)
        #expect(store.state.day?.dayStart == dayStart(monday))
    }

    // MARK: Places

    @Test func withoutAPlaceNothingLoads() async {
        places.lastKnown = nil
        let store = makeStore()

        await store.loadSelectedDay()

        #expect(provider.requestedDates.isEmpty)
        #expect(store.state.isLoading)
        #expect(store.state.day == nil)
    }

    @Test func aNewPlaceReloadsWhileKeepingTheDayOnScreen() async throws {
        let store = makeStore()
        await store.loadSelectedDay()
        let oldKey = store.loadKey
        places.current = chicago

        await store.locate()

        #expect(store.place == chicago)
        #expect(store.loadKey != oldKey)

        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()
        let loading = Task { await store.loadSelectedDay() }
        let request = try #require(await requests.next())

        #expect(store.state.isLoading)
        #expect(store.state.day?.dayStart == dayStart(monday))

        request.answer()
        await loading.value

        #expect(provider.requestedPlaces == [MockPlaceProvider.sanFrancisco, chicago])
        #expect(store.state.loadedDay != nil)
    }

    /// A relocation while a load is out: the old place's late answer is kept, but not shown.
    @Test func aStalePlacesResponseIsCachedButNotShown() async throws {
        provider.scenarios[chicago] = .allDayGolden
        let store = makeStore()
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        let loadingOld = Task { await store.loadSelectedDay() }
        let oldRequest = try #require(await requests.next())
        places.current = chicago
        await store.locate()
        let loadingNew = Task { await store.loadSelectedDay() }
        let newRequest = try #require(await requests.next())

        newRequest.answer()
        await loadingNew.value
        oldRequest.answer()
        await loadingOld.value

        #expect(store.state.loadedDay?.phaseSequence == SolarDay.mock(.allDayGolden).phaseSequence)
        #expect(provider.requestedPlaces == [MockPlaceProvider.sanFrancisco, chicago])

        provider.holdsResponses = false
        places.current = MockPlaceProvider.sanFrancisco
        await store.locate()
        await store.loadSelectedDay()

        #expect(provider.requestedPlaces.count == 2)
        #expect(store.state.loadedDay?.phaseSequence == SolarDay.mock().phaseSequence)
    }

    @Test func failingToLocateWithoutAPlaceFails() async {
        places.lastKnown = nil
        places.error = PlaceError.unavailable(timeZone: "GMT")
        let store = makeStore()

        await store.locate()

        #expect(store.state.failure as? PlaceError == .unavailable(timeZone: "GMT"))
    }

    @Test func failingToLocateWithAPlaceKeepsIt() async {
        places.error = PlaceError.unavailable(timeZone: "GMT")
        let store = makeStore()
        await store.loadSelectedDay()

        await store.locate()

        #expect(store.place == MockPlaceProvider.sanFrancisco)
        #expect(store.state.loadedDay != nil)
    }

    @Test func aCancelledLocateReportsNoFailure() async throws {
        places.lastKnown = nil
        places.holdsResponses = true
        var requests = places.heldRequests.makeAsyncIterator()
        let store = makeStore()

        let locating = Task { await store.locate() }
        let request = try #require(await requests.next())
        locating.cancel()
        request.fail(with: CancellationError())
        await locating.value

        #expect(store.state.isLoading)
    }

    /// Weather waits for a finished lookup, found or not, while a cancelled one waits for the
    /// lookup that replaces it.
    @Test func onlyFinishedLookupsCount() async throws {
        let store = makeStore()
        #expect(store.locatedCount == 0)

        await store.locate()
        places.error = PlaceError.unavailable(timeZone: "GMT")
        await store.locate()
        #expect(store.locatedCount == 2)

        places.error = nil
        places.holdsResponses = true
        var requests = places.heldRequests.makeAsyncIterator()
        let locating = Task { await store.locate() }
        let request = try #require(await requests.next())
        locating.cancel()
        request.fail(with: CancellationError())
        await locating.value

        #expect(store.locatedCount == 2)
    }

    /// Try Again without a place locates again, since there's nothing to load yet.
    @Test func reloadWithoutAPlaceLocatesAgain() {
        places.lastKnown = nil
        let store = makeStore()

        store.reload()

        #expect(store.locateCount == 1)
        #expect(store.reloadCount == 0)
    }

    // MARK: Time zones

    /// Travel changes the zone, which days are windowed to, and leaves the old zone's place behind.
    @Test func aTimeZoneChangeRelocatesThere() async throws {
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let tokyoCity = Place(latitude: 35.65, longitude: 139.73, source: .timeZone("Asia/Tokyo"))
        let tokyoFix = Place(latitude: 35.68, longitude: 139.77, source: .device)
        let store = makeStore()
        await store.loadSelectedDay()
        places.lastKnown = tokyoCity
        places.current = tokyoFix

        store.changeTimeZone(to: tokyo)

        #expect(store.calendar.timeZone == tokyo)
        #expect(store.place == tokyoCity)
        #expect(store.locateCount == 1)
        #expect(store.state.isLoading)
        #expect(store.state.day != nil)

        await store.locate()
        await store.loadSelectedDay()

        var tokyoCalendar = calendar
        tokyoCalendar.timeZone = tokyo
        #expect(places.requestedTimeZones == [tokyo])
        #expect(provider.requestedPlaces.last == tokyoFix)
        #expect(store.state.loadedDay?.dayStart == tokyoCalendar.startOfDay(for: monday))
        #expect(store.state.loadedDay?.calendar.timeZone == tokyo)
    }

    @Test func theSameTimeZoneChangesNothing() async throws {
        let store = makeStore()
        await store.loadSelectedDay()
        let key = store.loadKey

        store.changeTimeZone(to: try #require(TimeZone(identifier: calendar.timeZone.identifier)))

        #expect(store.loadKey == key)
        #expect(store.locateCount == 0)
        #expect(store.state.loadedDay != nil)
    }

    /// Reykjavik keeps GMT's offset all year, so its days start when GMT's do.
    @Test func aDayFromAnotherZoneIsntReused() async throws {
        let reykjavik = try #require(TimeZone(identifier: "Atlantic/Reykjavik"))
        let store = makeStore()
        await store.loadSelectedDay()
        let key = store.loadKey

        store.changeTimeZone(to: reykjavik)
        await store.loadSelectedDay()

        #expect(store.loadKey != key)
        #expect(provider.requestedDates == [dayStart(monday), dayStart(monday)])
        #expect(store.state.loadedDay?.calendar.timeZone == reykjavik)
    }

    // MARK: Days

    @Test func keepsThePreviousDayOnScreenWhileTheNextLoads() async throws {
        let store = makeStore()
        await store.loadSelectedDay()
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        store.selectedDate = tuesday
        let loading = Task { await store.loadSelectedDay() }
        let request = try #require(await requests.next())

        #expect(store.state.isLoading)
        #expect(store.state.day?.dayStart == dayStart(monday))

        request.answer()
        await loading.value

        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))
    }

    @Test func aLateResponseKeepsTheNewerSelectionAndIsCached() async throws {
        let store = makeStore()
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        let loadingMonday = Task { await store.loadSelectedDay() }
        let mondayRequest = try #require(await requests.next())
        store.selectedDate = tuesday
        let loadingTuesday = Task { await store.loadSelectedDay() }
        let tuesdayRequest = try #require(await requests.next())

        tuesdayRequest.answer()
        await loadingTuesday.value
        mondayRequest.answer()
        await loadingMonday.value

        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))

        provider.holdsResponses = false
        store.selectedDate = monday
        await store.loadSelectedDay()

        #expect(provider.requestedDates == [dayStart(monday), dayStart(tuesday)])
        #expect(store.state.loadedDay?.dayStart == dayStart(monday))
    }

    @Test func aLateFailureKeepsTheNewerSelection() async throws {
        let store = makeStore()
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        let loadingMonday = Task { await store.loadSelectedDay() }
        let mondayRequest = try #require(await requests.next())
        store.selectedDate = tuesday
        let loadingTuesday = Task { await store.loadSelectedDay() }
        let tuesdayRequest = try #require(await requests.next())

        tuesdayRequest.answer()
        await loadingTuesday.value
        mondayRequest.fail(with: StubError())
        await loadingMonday.value

        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))
    }

    @Test func aCancelledLoadReportsNoFailure() async throws {
        let store = makeStore()
        provider.holdsResponses = true
        var requests = provider.heldRequests.makeAsyncIterator()

        let loading = Task { await store.loadSelectedDay() }
        let request = try #require(await requests.next())
        loading.cancel()
        request.fail(with: CancellationError())
        await loading.value

        #expect(store.state.isLoading)
    }

    // MARK: Adjacent days

    @Test func theDaysEitherSideLoadAfterTheSelectedOne() async {
        let store = makeStore()
        await store.loadSelectedDay()
        await store.loadAdjacentDays()

        #expect(provider.requestedDates == [dayStart(monday), dayStart(sunday), dayStart(tuesday)])
    }

    @Test func heldDaysArentAskedForAgain() async {
        let store = makeStore()
        await store.loadSelectedDay()
        await store.loadAdjacentDays()
        store.selectedDate = tuesday
        await store.loadSelectedDay()
        await store.loadAdjacentDays()

        #expect(provider.requestedDates == [dayStart(monday), dayStart(sunday), dayStart(tuesday), dayStart(wednesday)])
    }

    /// A provider that failed the selected day isn't asked for more.
    @Test func theDaysEitherSideWaitForTheSelectedOne() async {
        let store = makeStore()
        await store.loadAdjacentDays()
        provider.error = StubError()
        await store.loadSelectedDay()
        await store.loadAdjacentDays()

        #expect(provider.requestedDates == [dayStart(monday)])
    }

    @Test func pagingToAHeldDayShowsItAtOnce() async {
        let store = makeStore()
        await store.loadSelectedDay()
        await store.loadAdjacentDays()

        #expect(store.selectDay(containing: dayStart(tuesday)))
        #expect(store.selectedDayStart == dayStart(tuesday))
        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))

        await store.loadSelectedDay()

        #expect(provider.requestedDates.count == 3)
        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))
    }

    @Test func pagingToADayNotHeldLeavesItToLoad() async {
        let store = makeStore()
        await store.loadSelectedDay()

        #expect(!store.selectDay(containing: dayStart(tuesday)))
        #expect(store.selectedDayStart == dayStart(tuesday))
        #expect(store.state.loadedDay?.dayStart == dayStart(monday))

        await store.loadSelectedDay()

        #expect(provider.requestedDates == [dayStart(monday), dayStart(tuesday)])
        #expect(store.state.loadedDay?.dayStart == dayStart(tuesday))
    }

    /// Reykjavik keeps GMT's offset all year, so its days start when the held GMT ones do.
    @Test func daysHeldForAnotherZoneArentPagedTo() async throws {
        let store = makeStore()
        await store.loadSelectedDay()
        await store.loadAdjacentDays()

        store.changeTimeZone(to: try #require(TimeZone(identifier: "Atlantic/Reykjavik")))

        #expect(!store.selectDay(containing: dayStart(tuesday)))
        #expect(store.state.isLoading)
    }
}

private extension SolarDayStore.LoadState {
    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    var loadedDay: SolarDay? {
        if case .loaded(let day) = self { day } else { nil }
    }

    var failure: (any Error)? {
        if case .failed(let error) = self { error } else { nil }
    }
}
