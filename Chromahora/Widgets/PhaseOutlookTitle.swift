//
//  PhaseOutlookTitle.swift
//  Chromahora
//

import SwiftUI

/// A golden or blue hour's name with its session's rating, as in "Golden hour · Great", or
/// "Golden · Great" where the full name won't fit, for the widgets and the watch. The rating
/// stands apart by weight rather than color, which a tinted Home Screen takes away. Without a
/// rating, the name alone.
struct PhaseOutlookTitle: View {
    let phase: DayPhase
    let rating: OutlookRating?

    var body: some View {
        if let rating {
            ViewThatFits(in: .horizontal) {
                title(phase.title, rating: rating)
                title(phase.shortTitle, rating: rating)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(phase.title), \(rating.title) outlook")
        } else {
            Text(phase.title)
                .lineLimit(1)
        }
    }

    private func title(_ name: String, rating: OutlookRating) -> some View {
        Text("\(name) · \(Text(rating.title).fontWeight(.regular))")
            .lineLimit(1)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        PhaseOutlookTitle(phase: .goldenHour, rating: .great)
        PhaseOutlookTitle(phase: .goldenHour, rating: .excellent)
            .frame(width: 120, alignment: .leading)
        PhaseOutlookTitle(phase: .blueHour, rating: nil)
    }
    .font(.subheadline.weight(.semibold))
    .padding()
}
