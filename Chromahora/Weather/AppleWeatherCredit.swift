//
//  AppleWeatherCredit.swift
//  Chromahora
//

import SwiftUI

/// The Apple Weather mark and a link to its other data sources, which WeatherKit's terms
/// require wherever its data shows. Named apart from WeatherKit's `WeatherAttribution`.
struct AppleWeatherCredit: View {
    /// The page WeatherKit's `WeatherAttribution.legalPageURL` reports, fixed here so the
    /// credit needs no request and shows offline.
    private static let legalPage = URL(string: "https://weatherkit.apple.com/legal-attribution.html")

    /// The mark itself, shared with `SourcesButton` so both read the same. A `Text`, so the
    /// button can swap it for another label inside one capsule.
    static var mark: Text {
        Text("\(Image(systemName: "apple.logo")) Weather")
            .accessibilityLabel("Apple Weather")
    }

    var body: some View {
        HStack(spacing: 6) {
            Self.mark
            if let legalPage = Self.legalPage {
                // Primary and underlined, since a bright sky through a popover's glass washes
                // out tinted text.
                Link("Other data sources", destination: legalPage)
                    .foregroundStyle(.primary)
                    .underline()
            }
        }
    }
}

#Preview {
    AppleWeatherCredit()
        .font(.footnote)
}
