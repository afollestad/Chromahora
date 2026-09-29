//
//  RulerScrim.swift
//  Chromahora
//

import SwiftUI

/// The darkened gutter behind the hour ruler, which keeps its white labels legible
/// over the bright daylight band. `DayTimeline` also paints it past the day's ends,
/// so overscrolling doesn't cut it off.
struct RulerScrim: View {
    let leadingInset: CGFloat
    /// Wide enough to sit behind the hour labels and the start of the marker labels over them.
    var width: CGFloat = 112

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.38), location: 0),
                .init(color: .black.opacity(0.2), location: 0.35),
                .init(color: .black.opacity(0.06), location: 0.7),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width + leadingInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

#Preview {
    RulerScrim(leadingInset: 0)
        .background(DayPhase.daylight.color)
}
