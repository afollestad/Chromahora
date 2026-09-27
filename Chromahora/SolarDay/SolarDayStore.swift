//
//  SolarDayStore.swift
//  Chromahora
//

import Foundation
import Observation

/// Loads the selected day's solar schedule from a provider, and keeps every day
/// it loads so returning to one doesn't wait on the provider again.
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

    /// The day to show. Any time within the day selects it.
    var selectedDate: Date
    private(set) var state: LoadState = .loading(nil)

    let calendar: Calendar
    private let provider: any SolarDayProvider
    @ObservationIgnored private var loadedDays: [Date: SolarDay] = [:]

    init(provider: any SolarDayProvider, calendar: Calendar = .current, selectedDate: Date = .now) {
        self.provider = provider
        self.calendar = calendar
        self.selectedDate = selectedDate
    }

    /// Identifies the selected day regardless of the time picked within it.
    var selectedDayStart: Date {
        calendar.startOfDay(for: selectedDate)
    }

    /// Shows the selected day, asking the provider only for days it hasn't loaded.
    ///
    /// The selection can move on while a request is out, so a response only
    /// shows if its day is still selected, though it's kept either way. A
    /// cancelled load reports no failure, since whatever cancelled it starts the next one.
    func loadSelectedDay() async {
        let dayStart = selectedDayStart
        if let day = loadedDays[dayStart] {
            state = .loaded(day)
            return
        }

        state = .loading(state.day)
        do {
            let day = try await provider.solarDay(for: dayStart, calendar: calendar)
            loadedDays[dayStart] = day
            if dayStart == selectedDayStart {
                state = .loaded(day)
            }
        } catch {
            if dayStart == selectedDayStart, !Task.isCancelled {
                state = .failed(error)
            }
        }
    }
}
