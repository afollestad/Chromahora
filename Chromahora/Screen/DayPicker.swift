//
//  DayPicker.swift
//  Chromahora
//

import SwiftUI

/// Calendar for choosing which day the timeline shows, with a shortcut back to today,
/// and a note of where the times are for and where they come from.
struct DayPicker: View {
    @Binding var selection: Date
    var place: Place?
    let onToday: () -> Void

    /// sunrise-sunset.org's terms ask for a link back.
    private static let source = URL(string: "https://sunrise-sunset.org")

    var body: some View {
        VStack(spacing: 8) {
            DatePicker("Day", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()

            Button("Today", action: onToday)
                .buttonStyle(.glass)

            VStack(spacing: 2) {
                if let place {
                    Text(place.summary)
                        .foregroundStyle(.secondary)
                }
                if let source = Self.source {
                    Link("Sun times by sunrise-sunset.org", destination: source)
                }
            }
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 320)
    }
}

#Preview {
    @Previewable @State var selection = Date.now
    DayPicker(selection: $selection, place: TimeZonePlaceProvider().lastKnownPlace(in: .current)) {}
}
