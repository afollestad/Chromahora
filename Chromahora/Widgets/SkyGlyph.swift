//
//  SkyGlyph.swift
//  Chromahora
//

import SwiftUI

/// The sky a phase comes under, where the forecast reaches it, as the timeline marks its
/// spells, or the phase's own dot where it doesn't.
struct SkyGlyph: View {
    let phase: DayPhase
    let spell: WeatherSpell?

    var body: some View {
        if let spell {
            Image(systemName: spell.condition.symbolName(inDaylight: phase == .goldenHour || phase == .daylight))
                // Not multicolor, whose yellow sun would vanish on a daylight sky.
                .symbolRenderingMode(.hierarchical)
                .accessibilityLabel(spell.title)
        } else {
            PhaseDot(phase: phase)
        }
    }
}

#Preview {
    let spell = WeatherSpell(condition: .partlyCloudy, interval: DateInterval(start: .now, duration: 3600), precipitationChance: 0, cloudCover: 0.5)
    HStack {
        SkyGlyph(phase: .goldenHour, spell: spell)
        SkyGlyph(phase: .blueHour, spell: spell)
        SkyGlyph(phase: .blueHour, spell: nil)
    }
}
