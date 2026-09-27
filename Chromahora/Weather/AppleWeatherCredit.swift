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

    var body: some View {
        HStack(spacing: 6) {
            Text("\(Image(systemName: "apple.logo")) Weather")
                .accessibilityLabel("Apple Weather")
            if let legalPage = Self.legalPage {
                Link("Other data sources", destination: legalPage)
            }
        }
    }
}

#Preview {
    AppleWeatherCredit()
        .font(.footnote)
}
