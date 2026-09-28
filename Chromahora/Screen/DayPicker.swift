//
//  DayPicker.swift
//  Chromahora
//

import SwiftUI

/// Calendar for choosing which day the timeline shows, with a shortcut back to today. Where
/// the times are for is the title's to say and change, and where they and the weather come
/// from is under the timeline's `SourcesButton`. It fills the calendar button's popover, and
/// tops the day panel in a wide window.
struct DayPicker: View {
    @Binding var selection: Date
    /// The store's, so the calendar marks today and picks days in the zone the days are windowed to.
    var calendar: Calendar = .current
    let onToday: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            DatePicker("Day", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                // Set on the picker alone, the only view that reads them. Left in the device's zone while
                // days are windowed to another, a tapped date would be built there and could land a day off.
                .environment(\.calendar, calendar)
                .environment(\.timeZone, calendar.timeZone)

            Button("Today", action: onToday)
                .buttonStyle(.glass)
        }
        .padding()
        .frame(width: 320)
        // Stops growing at accessibility1, like the timeline's labels and the other popovers, which
        // can't widen with their text.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

#Preview {
    @Previewable @State var selection = Date.now
    DayPicker(selection: $selection) {}
}
