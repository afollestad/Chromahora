//
//  DayPicker.swift
//  Chromahora
//

import SwiftUI

/// Calendar for choosing which day the timeline shows, with a shortcut back to today.
struct DayPicker: View {
    @Binding var selection: Date
    let onToday: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            DatePicker("Day", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()

            Button("Today", action: onToday)
                .buttonStyle(.glass)
        }
        .padding()
        .frame(width: 320)
    }
}

#Preview {
    @Previewable @State var selection = Date.now
    DayPicker(selection: $selection) {}
}
