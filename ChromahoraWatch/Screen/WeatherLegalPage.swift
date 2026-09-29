//
//  WeatherLegalPage.swift
//  ChromahoraWatch
//

import SwiftUI

/// WeatherKit's legal attribution, which its terms ask for wherever its weather shows. The phone
/// links to the legal page, which the watch can't open, so here it's the text WeatherKit offers
/// in its place, fetched when the page opens, as it lists every data source.
struct WeatherLegalPage: View {
    @State private var text: String?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            Group {
                if let text {
                    Text(text)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    // Offline, the page's address at least says where the sources are listed.
                    Text("Apple Weather lists its other data sources at \(legalPageAddress).")
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .scenePadding(.horizontal)
        }
        .navigationTitle("Apple Weather")
        .task {
            text = await WeatherKitProvider.legalAttributionText()
            isLoading = false
        }
    }

    /// The legal page without its scheme, for reading rather than opening.
    private var legalPageAddress: String {
        guard let page = AppleWeatherCredit.legalPage, let host = page.host() else {
            return "weatherkit.apple.com"
        }
        return host + page.path()
    }
}

#Preview {
    NavigationStack {
        WeatherLegalPage()
    }
}
