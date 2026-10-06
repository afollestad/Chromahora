//
//  WatchEndCard.swift
//  ChromahoraWatch
//

import SwiftUI

/// One end of the day as a card: its golden and blue hours and its sunrise or sunset on their
/// stretch of sky, zoomed to fill a panel, so the Crown doesn't scroll through hours of one
/// color to reach them. Leads with Apple Weather's mark while the panel shows weather, since
/// App Review looks for it wherever weather shows.
struct WatchEndCard: View {
    enum Kind {
        case morning
        case evening

        var title: String {
            switch self {
            case .morning: "Morning"
            case .evening: "Evening"
            }
        }
    }

    let kind: Kind
    let day: SolarDay
    let end: DayRun.End
    let now: Date
    /// The forecast's spells, of any day. Those reaching the stretch get a marker each.
    let weather: [WeatherSpell]

    /// The height the scroll view shows under the title, which the panel fills.
    @State private var visibleHeight: CGFloat = 0
    @State private var headerHeight: CGFloat = 0

    private static let spacing: CGFloat = 4

    /// Between the panel and the screen's bottom edge, which the card reaches past the safe area
    /// for, since five labels need more than the safe area leaves on a 46 mm watch.
    private static let bottomMargin: CGFloat = 6

    var body: some View {
        // A scroll view of its own rather than the page's, whose overflow scrolls the header under
        // the title without the edge effect that blurs it, as happens on a 40 mm watch when the
        // panel needs more room than the screen.
        ScrollView {
            VStack(alignment: .leading, spacing: Self.spacing) {
                header
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        headerHeight = height
                    }
                if let span {
                    WatchSkyPanel(day: day, span: span, now: now, weather: weather, fillHeight: panelHeight)
                } else {
                    none
                        .frame(height: max(panelHeight, 80))
                }
            }
            .padding(.bottom, Self.bottomMargin)
        }
        // Measured inside `ignoresSafeArea`, so from under the title to the screen's bottom edge.
        // Its scroll geometry would report nothing for content that doesn't scroll.
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            visibleHeight = height
        }
        .ignoresSafeArea(edges: .bottom)
        .containerBackground(DayPhase.night.color.gradient, for: .tabView)
        .environment(\.colorScheme, .dark)
    }

    /// The end's name with Apple Weather's mark beside it, or under it where large text leaves
    /// no room, rather than break the name.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                title
                Spacer(minLength: 4)
                weatherMark
            }
            VStack(alignment: .leading, spacing: 0) {
                title
                weatherMark
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 6)
        // Clear of the page dots beside the Crown.
        .padding(.trailing, 14)
    }

    private var title: some View {
        Text(kind.title)
            .font(.headline)
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var weatherMark: some View {
        if showsWeather {
            AppleWeatherCredit.mark
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
    }

    /// What's left of the screen under the header.
    private var panelHeight: CGFloat {
        visibleHeight - headerHeight - Self.spacing - Self.bottomMargin
    }

    /// From the first golden or blue hour's start to the sunrise or sunset or where the last ends,
    /// kept to the day, since the sky past midnight is another day's. Nil when the end has none
    /// of them, as near the poles.
    private var span: DateInterval? {
        let dates = end.magicHours.flatMap { [$0.interval.start, min($0.interval.end, day.dayEnd)] } + [end.event?.date].compactMap(\.self)
        guard let start = dates.min(), let last = dates.max() else {
            return nil
        }
        return DateInterval(start: start, end: last)
    }

    private var showsWeather: Bool {
        span.map { !WatchSkyPanel.spells(in: weather, reaching: $0, on: day).isEmpty } ?? false
    }

    /// The day's sky at the end's middle, in the panel's place, saying there's nothing to show.
    private var none: some View {
        let middle = kind == .morning ? 0.25 : 0.75
        let sky = SkyGradient.color(at: middle, in: day)
        return Text(kind == .morning ? "No golden or blue hour this morning" : "No golden or blue hour this evening")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(sky, in: WatchSkyPanel.shape)
            .environment(\.colorScheme, SkyGradient.labelScheme(over: sky))
    }
}

#Preview {
    @Previewable @State var card = 0
    let now = Date.now
    let day = SolarDay.mock(for: now)
    let ends = DayRun(day).ends(of: day)
    TabView(selection: $card) {
        WatchEndCard(kind: .morning, day: day, end: ends.morning, now: now, weather: WeatherSpell.mock())
            .tag(0)
        WatchEndCard(kind: .evening, day: day, end: ends.evening, now: now, weather: WeatherSpell.mock())
            .tag(1)
    }
    .tabViewStyle(.verticalPage)
}
