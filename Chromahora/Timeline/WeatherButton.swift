//
//  WeatherButton.swift
//  Chromahora
//

import SwiftUI

/// A weather spell's icon among the timeline's markers, which opens a popover describing
/// the spell. VoiceOver reads the same description as the button's label.
struct WeatherButton: View {
    let spell: WeatherSpell
    /// When the spell runs, as the timeline words it for the day.
    let range: String
    /// Whether the spell starts in daylight or golden hour, which shows a sun rather than a moon.
    let inDaylight: Bool
    /// The scheme of the sky behind the capsule, which the overlay picks for every label.
    /// Only the capsule takes it, so the popover keeps the system's.
    let scheme: ColorScheme

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            // The same font and padding as the overlay's text labels, so the capsule is as
            // tall as theirs and marker spacing holds.
            Text("\(Image(systemName: spell.condition.symbolName(inDaylight: inDaylight)))")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .glassEffect(.regular.interactive(), in: Capsule())
                .environment(\.colorScheme, scheme)
                // A taller target than the capsule, without widening what the overlay measures.
                .padding(.vertical, 10)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(description)
        .popover(isPresented: $isPresented, arrowEdge: .leading) {
            WeatherDetails(spell: spell, range: range, inDaylight: inDaylight)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var description: String {
        [spell.title, range, spell.summary].compactMap(\.self).joined(separator: ", ")
    }
}

/// The popover's content: the condition, when it runs, the detail worth knowing, and the credit.
private struct WeatherDetails: View {
    let spell: WeatherSpell
    let range: String
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
        .padding()
        // Stops growing at accessibility1, like the timeline's labels. Past it, the popover runs
        // out of room beside its marker and truncates the time range and the credit.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

#Preview {
    let spell = WeatherSpell.mock()[3]
    WeatherButton(spell: spell, range: "3:00 – 5:00 PM", inDaylight: true, scheme: .light)
        .padding()
        .background(DayPhase.daylight.color)
}
