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
            Self.glyph(for: spell.condition, inDaylight: inDaylight)
                .glassEffect(.regular.interactive(), in: Capsule())
                .environment(\.colorScheme, scheme)
                // A taller target than the capsule, without widening what the overlay measures.
                .padding(.vertical, 10)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spell.description(range: range))
        .popover(isPresented: $isPresented, arrowEdge: .leading) {
            WeatherSpellDetails(spell: spell, range: range, inDaylight: inDaylight)
                .padding()
                // Stops growing at accessibility1, like the timeline's labels. Past it, the popover runs
                // out of room beside its marker and truncates the time range and the credit.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .popoverContent()
        }
    }

    /// The icon padded to fill its capsule, which the overlay also cuts out of the lines behind it.
    /// The same font and padding as the overlay's text labels, so the capsule is as tall as
    /// theirs and marker spacing holds.
    static func glyph(for condition: SkyCondition, inDaylight: Bool) -> some View {
        Text("\(Image(systemName: condition.symbolName(inDaylight: inDaylight)))")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
    }
}

#Preview {
    let spell = WeatherSpell.mock()[3]
    WeatherButton(spell: spell, range: "3:00 – 5:00 PM", inDaylight: true, scheme: .light)
        .padding()
        .background(DayPhase.daylight.color)
}
