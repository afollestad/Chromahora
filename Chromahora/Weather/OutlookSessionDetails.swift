//
//  OutlookSessionDetails.swift
//  Chromahora
//

import SwiftUI

/// What a rated phase label opens to: the session's rating, its cloud cover, every reason for
/// the rating, and the credit, which the service's terms require wherever its weather shows.
/// Titled by the session rather than the phase, since a morning's rating covers its blue hour too.
struct OutlookSessionDetails: View {
    let session: OutlookSession

    private static let percent = FloatingPointFormatStyle<Double>.Percent().precision(.fractionLength(0))

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("\(session.kind.title) · \(session.rating.title)", systemImage: session.kind.symbolName)
                .font(.headline)
            Text("\(Image(systemName: "cloud")) \(session.cloudCover.formatted(Self.percent)) cloud")
                .monospacedDigit()
                .accessibilityLabel("\(session.cloudCover.formatted(Self.percent)) cloud cover")
            ForEach(session.reasons, id: \.self) { reason in
                Text(reason)
            }
            AppleWeatherCredit()
                .font(.footnote)
                .padding(.top, 8)
        }
        // Wraps a long reason in a popover beside a label, which leaves less than its width.
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    let sessions = PhotoOutlook.sessions(on: .mock(), hours: SkyHour.mock())
    VStack(alignment: .leading, spacing: 24) {
        ForEach(sessions) { session in
            OutlookSessionDetails(session: session)
        }
    }
    .padding()
}
