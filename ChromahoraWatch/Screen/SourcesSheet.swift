//
//  SourcesSheet.swift
//  ChromahoraWatch
//

import SwiftUI

/// Where the watch's sun times, weather and town come from, with each service's credit. The
/// watch can't open web pages, so it names each source in text, and in place of the phone's
/// link to WeatherKit's legal page opens a page of the legal text WeatherKit offers for that.
struct SourcesSheet: View {
    /// Whether the day shows weather, which is when Apple Weather's credit belongs here.
    let showsWeather: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // A non-breaking hyphen, so the address never breaks across lines.
                    section("Sun Times") {
                        Text("Sunrise, sunset and the golden and blue hours come from sunrise\u{2011}sunset.org.")
                    }
                    if showsWeather {
                        VStack(alignment: .leading, spacing: 8) {
                            section("Weather") {
                                Text("Clouds, fog and the chance of rain or snow come from Apple Weather.")
                                AppleWeatherCredit.mark
                                    .foregroundStyle(.primary)
                            }
                            NavigationLink("Other Data Sources") {
                                WeatherLegalPage()
                            }
                        }
                    }
                    section("Places") {
                        Text("The town you're in is named by Apple Maps.")
                        Text("\(Image(systemName: "apple.logo")) Maps")
                            .accessibilityLabel("Apple Maps")
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .scenePadding(.horizontal)
            }
            .navigationTitle("Sources")
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content()
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SourcesSheet(showsWeather: true)
}
