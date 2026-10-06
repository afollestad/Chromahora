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
    /// Where days are loaded for: the device's place, or one the person chose. Nil until the
    /// place provider has anything to go on.
    private(set) var place: Place?
    /// Where the day on screen is for, which lags `place` while a new place's day loads. Weather
    /// is matched against it, so another place's forecast never marks the day still shown.
    private(set) var shownPlace: Place?
    private(set) var reloadCount = 0
    /// Keys the view's locate task, so `reload()` can locate again when there's no place, a time
    /// zone change can locate in the new zone, and choosing a place cancels a lookup still out.
    private(set) var locateCount = 0
    /// Counts lookups that finished, found or not. Weather waits for one, so it never spends
    /// a request on the stored place the device may have left.
    private(set) var locatedCount = 0
    /// Numbers each device lookup as it starts.
    @ObservationIgnored private var lookupsStarted = 0
    /// The newest device lookup's number while it's out. A lookup it replaced can still be out
    /// beside it, but that one's answer is dropped, so only the newest can move the place.
    @ObservationIgnored private var newestLookupOut: Int?

    /// Days are windowed to its time zone: the device's, which `changeTimeZone(to:)` follows, or a
    /// chosen place's own.
    private(set) var calendar: Calendar
    /// The device's zone, which days return to when a chosen place is let go. It follows the
    /// device even while a chosen place holds the calendar.
    private(set) var deviceTimeZone: TimeZone
    private let provider: any SolarDayProvider
    private let placeProvider: any PlaceProvider
    /// Observed, so a view showing a neighbor through `loadedDay(offsetBy:from:)` updates once
    /// `loadAdjacentDays()` brings it in.
    private var loadedDays: [DayKey: SolarDay] = [:]

    init(
        provider: any SolarDayProvider,
        placeProvider: any PlaceProvider,
        calendar: Calendar = .current,
        selectedDate: Date = .now
    ) {
        self.provider = provider
        self.placeProvider = placeProvider
        self.calendar = calendar
        deviceTimeZone = calendar.timeZone
        self.selectedDate = selectedDate
        place = placeProvider.lastKnownPlace(in: calendar.timeZone)
    }

    /// Whether days are for a place the person chose rather than the device's.
    var isPlaceChosen: Bool {
        if case .chosen = place?.source { true } else { false }
    }

    /// Whether weather may load for `place`: a lookup has finished, and none is out that could
    /// still move it, which none can while a place is chosen. Until then the place may be a stored
    /// fix or a time zone's city the device has left, and a forecast for it would spend a request
    /// for nothing.
    var isPlaceSettled: Bool {
        locatedCount > 0 && (isPlaceChosen || newestLookupOut == nil)
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
    ///
    /// A chosen place is already known, so it counts as found at once, which lets weather load
    /// for it, and the device isn't asked. An answer that arrives cancelled or after a place was
    /// chosen is dropped: whatever cancelled the lookup starts the next one, possibly in another
    /// zone, and the choice wins.
    func locate() async {
        guard !isPlaceChosen else {
            if !Task.isCancelled {
                locatedCount += 1
            }
            return
        }
        lookupsStarted += 1
        let lookup = lookupsStarted
        newestLookupOut = lookup
        let found: Result<Place, any Error>
        do {
            found = .success(try await placeProvider.currentPlace(in: deviceTimeZone))
        } catch {
            found = .failure(error)
        }
        if newestLookupOut == lookup {
            newestLookupOut = nil
        }
        guard !Task.isCancelled, !isPlaceChosen else {
            return
        }
        switch found {
        case .success(let place):
            self.place = place
        case .failure(let error):
            if place == nil {
                state = .failed(error)
            }
        }
        locatedCount += 1
    }

    /// Shows days for `place`, a place the person searched for, windowed to its own zone. The
    /// day on screen stays until the place's loads, and a lookup still out for the device is
    /// cancelled, so its answer can't replace the choice. Choosing the place already shown, or
    /// one with no zone, changes nothing.
    func choose(_ place: Place, now: Date) {
        guard let timeZone = place.timeZone, place != self.place else {
            return
        }
        moveCalendar(to: timeZone, now: now)
        self.place = place
        state = .loading(state.day)
        locateCount += 1
    }

    /// Lets a chosen place go, returning to the device's place and zone and looking for the device
    /// again. Without any device place to go on, the screen clears rather than keep the chosen
    /// place's day under the device's title.
    func useCurrentLocation(now: Date) {
        guard isPlaceChosen else {
            return
        }
        moveCalendar(to: deviceTimeZone, now: now)
        place = placeProvider.lastKnownPlace(in: deviceTimeZone)
        state = place == nil ? .loading(nil) : .loading(state.day)
        locateCount += 1
    }

    /// Windows days to `timeZone` after the device's zone changes, as travel can while the app
    /// is suspended. The place restarts from what the provider knows in the new zone,
    /// since a fix from the old one is likely far behind, and a lookup still running in the old
    /// zone restarts too, so its fix isn't remembered under the wrong zone.
    ///
    /// A chosen place keeps its own zone, and only the device's is noted, for when it's let go.
    func changeTimeZone(to timeZone: TimeZone) {
        guard timeZone.identifier != deviceTimeZone.identifier else {
            return
        }
        deviceTimeZone = timeZone
        guard !isPlaceChosen else {
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
            shownPlace = place
            return
        }

        state = .loading(state.day)
        do {
            let day = try await provider.solarDay(for: key.dayStart, at: place, calendar: calendar)
            loadedDays[key] = day
            if key == currentKey {
                state = .loaded(day)
                shownPlace = place
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
    /// It goes by the date `day` reads in its own calendar. After the zone changes, with the
    /// device's or to a chosen place's, a day from the old zone stays on screen until the new
    /// zone's loads, and in a zone to the west the midnight that ends it still falls on that same date.
    func selectDay(offsetBy offset: Int, from day: SolarDay) -> Bool {
        guard let target = date(offsetBy: offset, from: day) else {
            return false
        }
        selectedDate = target
        guard let key = currentKey, let loaded = loadedDays[key] else {
            return false
        }
        state = .loaded(loaded)
        shownPlace = key.place
        return true
    }

    /// The day `offset` days from `day` for the current place, if it's loaded, without selecting
    /// it, so a pager can show a neighbor `loadAdjacentDays()` holds before it's paged to.
    func loadedDay(offsetBy offset: Int, from day: SolarDay) -> SolarDay? {
        guard let place, let target = date(offsetBy: offset, from: day) else {
            return nil
        }
        return loadedDays[DayKey(place: place, dayStart: calendar.startOfDay(for: target), timeZone: calendar.timeZone)]
    }

    /// Selects today again once the clock passes midnight, if the selection was on the day
    /// before, so a screen that stays open overnight, as the watch's does in memory, follows
    /// today rather than stay on yesterday. A day paged to stays. Today shows at once if it's
    /// held, as the neighbor `loadAdjacentDays()` loaded usually is.
    ///
    /// `previous` is the time the screen last read as now.
    func advanceToToday(from previous: Date, to now: Date) {
        guard !calendar.isDate(previous, inSameDayAs: now), calendar.isDate(selectedDate, inSameDayAs: previous) else {
            return
        }
        selectedDate = now
        if let key = currentKey, let loaded = loadedDays[key] {
            state = .loaded(loaded)
            shownPlace = key.place
        }
    }

    /// Windows days to `timeZone`, keeping the day the person was looking at: today stays today,
    /// as it reads there, and any other day keeps its date.
    private func moveCalendar(to timeZone: TimeZone, now: Date) {
        let previous = calendar
        calendar.timeZone = timeZone
        if previous.isDate(selectedDate, inSameDayAs: now) {
            selectedDate = now
        } else if let date = noon(onDateOf: selectedDate, in: previous) {
            selectedDate = date
        }
    }

    /// Noon in this store's calendar on the date `offset` days from `day`, as `day` reads it.
    private func date(offsetBy offset: Int, from day: SolarDay) -> Date? {
        day.calendar.date(byAdding: .day, value: offset, to: day.dayStart).flatMap { noon(onDateOf: $0, in: day.calendar) }
    }

    /// Noon in this store's calendar on the date `date` reads in `calendar`. Noon, since some
    /// zones skip midnight when daylight saving time starts.
    private func noon(onDateOf date: Date, in calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.era, .year, .month, .isLeapMonth, .day], from: date)
        components.hour = 12
        return self.calendar.date(from: components)
    }

    private var currentKey: DayKey? {
        place.map { DayKey(place: $0, dayStart: selectedDayStart, timeZone: calendar.timeZone) }
    }
}
