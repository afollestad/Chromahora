//
//  OutlookLabel.swift
//  Chromahora
//

import SwiftUI

/// An outlook's rating and the cloud cover beside it, as in "Great · ☁︎ 10%", or either alone,
/// in the few words a widget or the watch has room for. The cloud is outlined, apart from the
/// filled sky glyphs it sits near, and VoiceOver names what each figure is.
struct OutlookLabel: View {
    var rating: OutlookRating?
    /// The share of the sky covered, from 0 to 1.
    var cloudCover: Double?

    private static let percent = FloatingPointFormatStyle<Double>.Percent().precision(.fractionLength(0))

    var body: some View {
        text
            .monospacedDigit()
            .accessibilityLabel(Self.spoken(rating: rating, cloudCover: cloudCover))
    }

    private var text: Text {
        let cloud = cloudCover.map { Text("\(Image(systemName: "cloud")) \($0.formatted(Self.percent))") }
        return switch (rating, cloud) {
        case let (rating?, cloud?): Text("\(rating.title) · \(cloud)")
        case let (rating?, nil): Text(rating.title)
        case let (nil, cloud?): cloud
        case (nil, nil): Text(verbatim: "")
        }
    }

    /// What VoiceOver reads, as in "Great outlook, 10% cloud cover".
    static func spoken(rating: OutlookRating?, cloudCover: Double?) -> String {
        [rating.map { "\($0.title) outlook" }, cloudCover.map { "\($0.formatted(percent)) cloud cover" }]
            .compactMap(\.self)
            .joined(separator: ", ")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        OutlookLabel(rating: .great, cloudCover: 0.1)
        OutlookLabel(rating: .poor)
        OutlookLabel(cloudCover: 0.72)
    }
    .font(.caption)
    .padding()
}
