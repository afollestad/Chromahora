//
//  WidgetCredit.swift
//  Chromahora
//

import SwiftUI

/// The credits both services' terms ask for wherever their data shows, as `SourcesButton` gives
/// them in the app: sunrise-sunset.org on every widget, led by the Apple Weather mark while the
/// widget shows weather, since App Review looks for the mark wherever weather shows.
struct WidgetCredit: View {
    let showsWeather: Bool
    /// Links each credit to its page, as both services ask. WidgetKit takes links only in medium
    /// widgets and larger; a small one opens the app, whose sources popover links them.
    var linksSources = false

    var body: some View {
        // One line where it fits, as in the app's capsule, and a line each on a small widget.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                if showsWeather {
                    mark
                    Text(" · ")
                        .accessibilityHidden(true)
                }
                site
            }
            VStack(alignment: .leading, spacing: 0) {
                if showsWeather {
                    mark
                }
                site
            }
        }
        .font(.caption2)
        // Primary rather than the accent, which a golden-hour sky would swallow.
        .foregroundStyle(.primary)
        .lineLimit(1)
        // Shrinks rather than truncates at large sizes, since the terms want the credit whole.
        .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private var mark: some View {
        if linksSources, let legalPage = AppleWeatherCredit.legalPage {
            Link(destination: legalPage) {
                AppleWeatherCredit.mark
            }
        } else {
            AppleWeatherCredit.mark
        }
    }

    @ViewBuilder
    private var site: some View {
        if linksSources, let siteURL = SunriseSunsetClient.siteURL {
            Link("sunrise-sunset.org", destination: siteURL)
        } else {
            Text("sunrise-sunset.org")
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        WidgetCredit(showsWeather: true)
        WidgetCredit(showsWeather: false)
        WidgetCredit(showsWeather: true)
            .frame(width: 120, alignment: .leading)
    }
}
