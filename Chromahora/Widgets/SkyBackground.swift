//
//  SkyBackground.swift
//  Chromahora
//

import SwiftUI
import WidgetKit

/// The sky at an entry's moment, flat, as the app's timeline paints it there, so a widget's
/// color says the time of day the way the app does.
struct SkyBackground: View {
    let entry: SkyEntry

    var body: some View {
        if let color = Self.color(of: entry) {
            color
        } else {
            Rectangle()
                .fill(.background)
        }
    }

    /// The sky's color at `date`, as the timeline paints it there. A date past the run keeps
    /// its nearest day's end.
    static func color(at date: Date, in run: DayRun) -> Color {
        let day = run.day(containing: date) ?? (date < run.start ? run.days[0] : run.days[run.days.count - 1])
        return SkyGradient.color(at: day.fraction(of: date), in: day)
    }

    /// Nil for an entry with no sun times to color it.
    static func color(of entry: SkyEntry) -> Color? {
        guard case .loaded(let content) = entry.state else {
            return nil
        }
        return color(at: entry.date, in: content.run)
    }
}

/// Gives a widget's text the scheme that reads over its sky, since dark text on night or white
/// on daylight would vanish. Only while the widget shows its own background in full color: a
/// tinted or clear Home Screen, or StandBy, takes the background away and colors the text itself.
private struct SkyScheme: ViewModifier {
    let sky: Color?
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground

    func body(content: Content) -> some View {
        if let sky, renderingMode == .fullColor, showsBackground {
            content.environment(\.colorScheme, SkyGradient.labelScheme(over: sky))
        } else {
            content
        }
    }
}

extension View {
    /// Sits a widget's content on the sky at `entry`'s moment, in the scheme that reads over it.
    func skyWidgetBackground(for entry: SkyEntry) -> some View {
        modifier(SkyScheme(sky: SkyBackground.color(of: entry)))
            .containerBackground(for: .widget) {
                SkyBackground(entry: entry)
            }
    }
}

#Preview {
    let now = Date.now
    SkyBackground(entry: SkyEntry(date: now, state: .loaded(.preview(at: now))))
        .frame(width: 170, height: 170)
}
