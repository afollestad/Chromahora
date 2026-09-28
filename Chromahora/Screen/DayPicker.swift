//
//  DayPicker.swift
//  Chromahora
//

import SwiftUI

/// Calendar for choosing which day the timeline shows, with a shortcut back to today,
/// and a note of where the times are for and where they and the weather come from.
struct DayPicker: View {
    @Binding var selection: Date
    var place: Place?
    let onToday: () -> Void

    /// sunrise-sunset.org's terms ask for a link back.
    private static let source = URL(string: "https://sunrise-sunset.org")
    private static let settings = URL(string: UIApplication.openSettingsURLString)

    var body: some View {
        VStack(spacing: 8) {
            DatePicker("Day", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()

            Button("Today", action: onToday)
                .buttonStyle(.glass)

            // Primary, with underlined links, since a bright sky through the glass washes out
            // gray and tinted text.
            VStack(spacing: 2) {
                if let place {
                    Text(place.summary)
                    // An approximate place usually means location is off for the app.
                    if case .timeZone = place.source, let settings = Self.settings {
                        Link("Use Your Location in Settings", destination: settings)
                            .foregroundStyle(.primary)
                            .underline()
                    }
                }
                if let source = Self.source {
                    Link("Sun times by sunrise-sunset.org", destination: source)
                        .foregroundStyle(.primary)
                        .underline()
                }
                AppleWeatherCredit()
            }
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 320)
        // Stops growing at accessibility1, like the timeline's labels. A popover can't outgrow
        // the screen, so past it the footer truncates to a word or two a line.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

#Preview {
    @Previewable @State var selection = Date.now
    DayPicker(selection: $selection, place: TimeZonePlaceProvider().lastKnownPlace(in: .current)) {}
}
