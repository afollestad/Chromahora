//
//  SolarDayStore.swift
//  Chromahora
//

import Foundation
import Observation

/// Loads the selected day's solar schedule for the current place from a provider, and
/// keeps every day it loads so returning to one doesn't wait on the provider again.
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

    /// Identifies a load, so a view's `task(id:)` restarts whenever the place or day
    /// changes, or `reload()` asks again.
    struct LoadKey: Hashable {
        let place: Place?
        let dayStart: Date
        let reloadCount: Int
    }

    /// A day's times depend on where they're for as well as the date.
    private struct DayKey: Hashable {
        let place: Place
        let dayStart: Date
    }

    /// The day to show. Any time within the day selects it.
    var selectedDate: Date
    private(set) var state: LoadState = .loading(nil)
    /// Where days are loaded for. Nil until the place provider has anything to go on.
    private(set) var place: Place?
    private(set) var reloadCount = 0
    /// Keys the view's locate task, so `reload()` can locate again when there's no place.
    private(set) var locateCount = 0

    let calendar: Calendar
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
        LoadKey(place: place, dayStart: selectedDayStart, reloadCount: reloadCount)
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
        let key = DayKey(place: place, dayStart: selectedDayStart)
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

    private var currentKey: DayKey? {
        place.map { DayKey(place: $0, dayStart: selectedDayStart) }
    }
}
