//
//  PhaseDot.swift
//  Chromahora
//

import SwiftUI

/// A phase's color as a dot, as the day's details list it. Its ring is stronger than theirs,
/// since a widget's sky is often the dot's own color.
struct PhaseDot: View {
    let phase: DayPhase

    var body: some View {
        Circle()
            .fill(phase.color)
            .strokeBorder(.primary.opacity(0.35), lineWidth: 0.5)
            .frame(width: 10, height: 10)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        PhaseDot(phase: .blueHour)
        PhaseDot(phase: .goldenHour)
    }
    .padding()
    .background(DayPhase.goldenHour.color)
}
