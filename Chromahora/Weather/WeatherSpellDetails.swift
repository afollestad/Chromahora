//
//  WeatherSpellDetails.swift
//  Chromahora
//

import SwiftUI

/// What a weather spell's marker opens to: the condition, when it runs, the detail worth
/// knowing, and the credit, which the service's terms require wherever its weather shows.
struct WeatherSpellDetails: View {
    let spell: WeatherSpell
    /// When the spell runs, as the timeline words it for the day.
    let range: String
    /// Whether the spell starts in daylight or golden hour, which shows a sun rather than a moon.
    let inDaylight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(spell.title, systemImage: spell.condition.symbolName(inDaylight: inDaylight))
                .font(.headline)
            // The range reads mid-sentence elsewhere, as in "until 4:00 AM", so it starts a line here capitalized.
            Text(range.prefix(1).uppercased() + range.dropFirst())
            if let summary = spell.summary {
                Text(summary)
            }
            AppleWeatherCredit()
                .font(.footnote)
                .padding(.top, 8)
        }
    }
}

#Preview {
    WeatherSpellDetails(spell: WeatherSpell.mock()[3], range: "3:00 – 5:00 PM", inDaylight: true)
        .padding()
}
