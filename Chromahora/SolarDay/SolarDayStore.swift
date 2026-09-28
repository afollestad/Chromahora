//
//  SolarDayStore.swift
//  Chromahora
//

import Foundation
import Observation

/// Loads the selected day's solar schedule for the current place from a provider, and
/// keeps every day it loads so returning to one doesn't wait on the provider again. It
/// also loads the days either side, so pulling the timeline through an end shows one at once.
@Observable
final class SolarDayStore {
    enum LoadState {
        /// Waiting on the provider. Carries the day still on screen, if any, so
        /// the timeline doesn't blank out while moving between days.
        case loading(SolarDay?)
        case loaded(SolarDay)
        case failed(any Error)

        /// The day to draw: the loaded one, or while another loads, the one still on screen.
        var day: SolarDay? {
            switch self {
            case .loading(let previous): previous
            case .loaded(let day): day
            case .failed: nil
            }
        }
    }

    /// Identifies a load, so a view's `task(id:)` restarts whenever the place, day or time
    /// zone changes, or `reload()` asks again.
    struct LoadKey: Hashable {
        let place: Place?
        let dayStart: Date
        let timeZone: TimeZone
        let reloadCount: Int
    }

    /// A day's times depend on where they're for and the zone they're windowed to, as well
    /// as the date. Zones can share a day's start, so the start alone can't tell them apart.
    private struct DayKey: Hashable {
        let place: Place
        let dayStart: Date
        let timeZone: TimeZone
    }

    /// The day to show. Any time within the day selects it.
    var selectedDate: Date
    private(set) var state: LoadState = .loading(nil)
    /// Where days are loaded for. Nil until the place provider has anything to go on.
    private(set) var place: Place?
    private(set) var reloadCount = 0
    /// Keys the view's locate task, so `reload()` can locate again when there's no place,
    /// and a time zone change can locate in the new zone.
    private(set) var locateCount = 0
    /// Counts lookups that finished, found or not. Weather waits for one, so it never spends
    /// a request on the stored place the device may have left.
    private(set) var locatedCount = 0

    /// Days are windowed to its time zone, which follows the device's through `changeTimeZone(to:)`.
    private(set) var calendar: Calendar
    private let provider: any SolarDayProvider
    private let placeProvider: any PlaceProvider
    @ObservationIgnored private var loadedDays: [DayKey: SolarDay] = [:]

    init(
        provider: any SolarDayProvider,
        placeProvider: any PlaceProvider,
        calendar: Calendar = .current,
        selectedDate: Date = .now
    ) {
        self.provider = provider
        self.placeProvider = placeProvider
        self.calendar = calendar
        self.selectedDate = selectedDate
        place = placeProvider.lastKnownPlace(in: calendar.timeZone)
    }

    /// Identifies the selected day regardless of the time picked within it.
    var selectedDayStart: Date {
        calendar.startOfDay(for: selectedDate)
    }

    var loadKey: LoadKey {
        LoadKey(place: place, dayStart: selectedDayStart, timeZone: calendar.timeZone, reloadCount: reloadCount)
    }

    /// Asks the place provider where the device is. A new place changes `loadKey`, which
    /// reloads the day. Without any place, a failure shows; with one, the day stays.
    func locate() async {
        do {
            place = try await placeProvider.currentPlace(in: calendar.timeZone)
        } catch {
            // Whatever cancelled the task starts the next one.
            if place == nil, !Task.isCancelled {
                state = .failed(error)
            }
        }
        // A cancelled lookup isn't finished, since whatever cancelled it starts the next one.
        if !Task.isCancelled {
            locatedCount += 1
        }
    }

    /// Windows days to `timeZone` after the device's zone changes, as travel can while the app
    /// is suspended. The place restarts from what the provider knows in the new zone,
    /// since a fix from the old one is likely far behind, and a lookup still running in the old
    /// zone restarts too, so its fix isn't remembered under the wrong zone.
    func changeTimeZone(to timeZone: TimeZone) {
        guard timeZone.identifier != calendar.timeZone.identifier else {
            return
        }
        calendar.timeZone = timeZone
        place = placeProvider.lastKnownPlace(in: timeZone)
        state = .loading(state.day)
        locateCount += 1
    }

    /// Loads the selected day again through the view's task, keeping any day on screen
    /// meanwhile, or locates again when there's no place yet. Restarting a task cancels
    /// a load still out, which an unstructured `Task` would leave running.
    func reload() {
        state = .loading(state.day)
        if place == nil {
            locateCount += 1
        } else {
            reloadCount += 1
        }
    }

    #if DEBUG
    /// Asks where the device is again, as returning to the app does.
    func relocate() {
        locateCount += 1
    }

    /// Forgets every loaded day and clears the screen, so the next load starts cold.
    func discardLoadedDays() {
        loadedDays = [:]
        state = .loading(nil)
    }
    #endif

    /// Shows the selected day, asking the provider only for days it hasn't loaded.
    ///
    /// The selection or place can move on while a request is out, so a response only
    /// shows if both still match, though it's kept either way. A cancelled load reports
    /// no failure, since whatever cancelled it starts the next one.
    func loadSelectedDay() async {
        guard let place else {
            return
        }
        let key = DayKey(place: place, dayStart: selectedDayStart, timeZone: calendar.timeZone)
        if let day = loadedDays[key] {
            state = .loaded(day)
            return
        }

        state = .loading(state.day)
        do {
            let day = try await provider.solarDay(for: key.dayStart, at: place, calendar: calendar)
            loadedDays[key] = day
            if key == currentKey {
                state = .loaded(day)
            }
        } catch {
            if key == currentKey, !Task.isCancelled {
                state = .failed(error)
            }
        }
    }

    /// Loads the days before and after the selected one, so paging to either shows it at once.
    ///
    /// Only once the selected day has loaded, so a failing or rate-limited provider isn't asked
    /// for more. A neighbor that fails is left for `loadSelectedDay()` to load if it's paged to.
    func loadAdjacentDays() async {
        guard let place, case .loaded(let shown) = state, shown.dayStart == selectedDayStart else {
            return
        }
        for offset in [-1, 1] {
            guard !Task.isCancelled,
                  let date = calendar.date(byAdding: .day, value: offset, to: selectedDayStart) else {
                return
            }
            let key = DayKey(place: place, dayStart: calendar.startOfDay(for: date), timeZone: calendar.timeZone)
            if loadedDays[key] == nil, let day = try? await provider.solarDay(for: key.dayStart, at: place, calendar: calendar) {
                loadedDays[key] = day
            }
        }
    }

    /// Selects the day `offset` days from `day`, and shows it at once if it's already loaded, so
    /// a page change and the day it shows can share one transaction. Returns whether it was;
    /// if not, `loadSelectedDay()` loads it as for any other selection.
    ///
    /// It goes by the date `day` reads in its own calendar. After `changeTimeZone(to:)`, a day
    /// from the old zone stays on screen until the new zone's loads, and in a zone to the west
    /// the midnight that ends it still falls on that same date.
    func selectDay(offsetBy offset: Int, from day: SolarDay) -> Bool {
        guard let date = day.calendar.date(byAdding: .day, value: offset, to: day.dayStart) else {
            return false
        }
        var components = day.calendar.dateComponents([.era, .year, .month, .isLeapMonth, .day], from: date)
        // Noon, since some zones skip midnight when daylight saving time starts.
        components.hour = 12
        guard let target = calendar.date(from: components) else {
            return false
        }
        selectedDate = target
        guard let key = currentKey, let loaded = loadedDays[key] else {
            return false
        }
        state = .loaded(loaded)
        return true
    }

    private var currentKey: DayKey? {
        place.map { DayKey(place: $0, dayStart: selectedDayStart, timeZone: calendar.timeZone) }
    }
}
