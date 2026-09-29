//
//  SourcesButton.swift
//  Chromahora
//

import SwiftUI

/// A quiet capsule at the foot of the timeline, which opens a popover saying where the sun and
/// moon times and weather come from, with the links both services' terms ask for. The capsule
/// itself names sunrise-sunset.org, whose terms want the credit shown visibly, and while the
/// timeline shows weather it leads with the Apple Weather mark, since App Review looks for
/// the mark wherever weather shows. A credit a tap away isn't enough for either.
struct SourcesButton: View {
    /// Whether the timeline shows weather, which puts the mark on the capsule and Apple
    /// Weather's credit in the popover.
    let showsWeather: Bool
    /// The scheme of the sky behind the capsule, which the timeline samples where it sits.
    /// Only the capsule takes it, so the popover keeps the system's.
    let scheme: ColorScheme

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            title
                // Regular rather than the labels' semibold, so the credit sits back from the day.
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .glassEffect(.regular.interactive(), in: Capsule())
                .environment(\.colorScheme, scheme)
                // A taller target than the capsule. It adds to the bar's height, and so to the
                // band the edge effect blurs, so it stops short of 44 pt.
                .padding(.vertical, 6)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Spelled out, so VoiceOver reads the logo as Apple Weather and skips the separator.
        .accessibilityLabel(showsWeather ? Text("Apple Weather and sunrise-sunset.org") : Text("sunrise-sunset.org"))
        .accessibilityHint(
            showsWeather ? Text("Shows where the sun and moon times and weather come from") : Text("Shows where the sun and moon times come from")
        )
        // The labels' cap, so the capsule never outgrows them.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .animation(.smooth, value: showsWeather)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            SourcesDetails(showsWeather: showsWeather)
                .popoverContent()
        }
    }

    /// One `Text` either way, so the capsule stretches between them rather than a second
    /// capsule fading in over the first.
    private var title: Text {
        showsWeather ? Text("\(AppleWeatherCredit.mark) · sunrise-sunset.org") : Text("sunrise-sunset.org")
    }
}

/// The popover's content: what each service provides, and its credit.
private struct SourcesDetails: View {
    let showsWeather: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sun and Moon")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("Sunrise, sunset, golden and blue hours, the moon and the dark sky come from sunrise-sunset.org.")
                if let sunSource = SunriseSunsetClient.siteURL {
                    // Primary and underlined, since a bright sky through a popover's glass washes
                    // out tinted text.
                    Link("sunrise-sunset.org", destination: sunSource)
                        .foregroundStyle(.primary)
                        .underline()
                }
            }
            if showsWeather {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weather")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("Clouds, fog, the chance of rain or snow, the UV index and visibility come from Apple Weather.")
                    AppleWeatherCredit()
                }
            }
        }
        .font(.subheadline)
        // Wide enough for the credit on one line at the default size, so sentences wrap evenly.
        .frame(width: 280, alignment: .leading)
        .padding()
        // Stops growing at accessibility1, like the timeline's labels. A popover can't outgrow
        // the screen, so past it the text truncates to a word or two a line.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

#Preview {
    HStack(spacing: 0) {
        SourcesButton(showsWeather: true, scheme: .light)
            .padding()
            .background(DayPhase.daylight.color)
        SourcesButton(showsWeather: false, scheme: .dark)
            .padding()
            .background(DayPhase.night.color)
    }
}
