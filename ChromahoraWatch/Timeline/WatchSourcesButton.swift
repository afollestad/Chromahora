//
//  WatchSourcesButton.swift
//  ChromahoraWatch
//

import SwiftUI

/// The credit at the foot of the day, which opens where the sun times and weather come from.
/// It always names sunrise-sunset.org, whose terms want the credit shown, and while the day
/// shows weather it leads with the Apple Weather mark, since App Review looks for the mark
/// wherever weather shows. A full-width button, one credit a line, as the phone's capsule
/// would wrap on the watch.
struct WatchSourcesButton: View {
    /// Whether the day shows weather, which puts the mark on the button and Apple Weather's
    /// credit in the sheet.
    let showsWeather: Bool

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            VStack(spacing: 2) {
                if showsWeather {
                    AppleWeatherCredit.mark
                }
                Text("sunrise-sunset.org")
            }
            .font(.footnote)
            .frame(maxWidth: .infinity)
        }
        // Spelled out, so VoiceOver reads the logo as Apple Weather.
        .accessibilityLabel(showsWeather ? Text("Apple Weather and sunrise-sunset.org") : Text("sunrise-sunset.org"))
        .accessibilityHint(showsWeather ? Text("Shows where the sun times and weather come from") : Text("Shows where the sun times come from"))
        .sheet(isPresented: $isPresented) {
            SourcesSheet(showsWeather: showsWeather)
        }
    }
}

#Preview {
    VStack {
        WatchSourcesButton(showsWeather: true)
        WatchSourcesButton(showsWeather: false)
    }
    .background(DayPhase.night.color)
}
