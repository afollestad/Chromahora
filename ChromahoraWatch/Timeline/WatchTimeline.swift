//
//  WatchTimeline.swift
//  ChromahoraWatch
//

import SwiftUI

/// One day's sky and its labels, which the Digital Crown scrolls, and at its foot the sources the
/// services' terms ask to be credited. It opens on the day's focus: now on today, otherwise the
/// middle of its brightest phase.
struct WatchTimeline: View {
    let day: SolarDay
    let now: Date
    /// The forecast's spells, of any day. Those overlapping this one get a marker each.
    let weather: [WeatherSpell]
    /// Scrolls whenever it changes: to the focus time for Today, or to a time a row of the
    /// details names.
    let focus: TimelineFocus

    /// Past the phone's 72, since the watch's labels share one column: at this zoom the changes
    /// of light around sunrise, often under half an hour apart, sit on or near their lines.
    static let pointsPerHour: CGFloat = 90

    /// Room above midnight for the label of a phase under way since then, which is centered on
    /// the day's first point.
    private static let edgeClearance: CGFloat = 16

    private let focusAnchorID = "focus"
    private let requestAnchorID = "request"
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        let height = day.duration / 3600 * Self.pointsPerHour
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: Self.edgeClearance)
                    WatchTimelineOverlay(day: day, now: now, weather: weather)
                        .frame(height: height)
                        .background(SkyGradient(day: day).overlay(dimming))
                        .overlay(alignment: .top) {
                            anchor(focusAnchorID, at: day.focusDate(now: now), in: height)
                        }
                        .overlay(alignment: .top) {
                            anchor(requestAnchorID, at: requestedDate, in: height)
                        }
                    WatchSourcesButton(showsWeather: showsWeather)
                        .padding(8)
                }
                // The sky runs on past both ends of the day, behind the clearance and the credit.
                .background {
                    VStack(spacing: 0) {
                        SkyGradient.color(at: 0, in: day)
                        endColor
                    }
                    .overlay(dimming)
                }
            }
            .onAppear {
                proxy.scrollTo(focusAnchorID, anchor: .center)
            }
            .onChange(of: focus) {
                withAnimation {
                    proxy.scrollTo(focus.date == nil ? focusAnchorID : requestAnchorID, anchor: .center)
                }
            }
        }
    }

    /// An invisible scroll target, whose padding keeps its one-point frame at `date`.
    private func anchor(_ id: String, at date: Date, in height: CGFloat) -> some View {
        Color.clear
            .frame(height: 1)
            .id(id)
            .padding(.top, height * day.fraction(of: date))
            .accessibilityHidden(true)
    }

    /// The time the details last asked for, or the focus time once the day no longer holds it.
    private var requestedDate: Date {
        focus.date.flatMap { day.contains($0) ? $0 : nil } ?? day.focusDate(now: now)
    }

    /// Always On dims the sky, as the system dims a watch face's colors.
    private var dimming: Color {
        .black.opacity(isLuminanceReduced ? 0.5 : 0)
    }

    /// The sky at midnight, which the credit sits on past the day's end.
    private var endColor: Color {
        SkyGradient.color(at: 1, in: day)
    }

    /// Whether any spell reaches the day, which is when the credit leads with Apple Weather's mark.
    private var showsWeather: Bool {
        weather.contains { $0.span(within: day) != nil }
    }
}

#Preview {
    let now = Date.now
    WatchTimeline(day: .mock(for: now), now: now, weather: WeatherSpell.mock(), focus: TimelineFocus())
}
