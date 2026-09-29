//
//  NextMagicHourView.swift
//  Chromahora
//

import SwiftUI

/// The small widget for the next golden or blue hour, laid out like Apple Weather's: the place,
/// the time it starts in large type, and below, the phase under the sky's glyph and how long
/// until it starts.
struct NextMagicHourView: View {
    let entry: SkyEntry

    var body: some View {
        WidgetContent(entry: entry) { content in
            VStack(alignment: .leading, spacing: 0) {
                MagicHourSummary(content: content, now: entry.date)
                Spacer(minLength: 4)
                WidgetCredit(showsWeather: MagicHourSummary.spell(in: content, at: entry.date) != nil)
            }
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    VStack(spacing: 16) {
        ForEach([16, 18, 22], id: \.self) { hour in
            let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
            let entry = SkyEntry(date: now, state: .loaded(.preview(at: now)))
            NextMagicHourView(entry: entry)
                .skyWidgetBackground(for: entry)
                .padding(16)
                .frame(width: 164, height: 164)
                .background(SkyBackground(entry: entry))
                .clipShape(.rect(cornerRadius: 24))
        }
    }
}
