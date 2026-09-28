//
//  DayPanel.swift
//  Chromahora
//

import SwiftUI

/// The day at a glance beside the timeline when the window has room, as on iPad or an opened
/// foldable: the calendar, then the day's phases, sunrise and sunset, and weather. It floats on
/// glass over the sky, and tapping a row scrolls the timeline to it.
struct DayPanel: View {
    /// `DayPicker`'s width, so the calendar sits in the panel as it does in its popover.
    static let width: CGFloat = 320
    /// The debug drawer's gap from the screen's edge, kept on every side the panel floats clear of.
    static let margin: CGFloat = 8
    /// How much of the trailing edge the panel takes from the timeline.
    static let footprint = width + margin

    let day: SolarDay?
    let now: Date
    @Binding var selectedDate: Date
    var place: Place?
    /// The forecast's spells, of any day. Those reaching this one are listed.
    var weather: [WeatherSpell] = []
    let onToday: () -> Void
    /// Scrolls the timeline to a time on the day.
    let onFocus: (Date) -> Void

    private let shape = RoundedRectangle(cornerRadius: 28)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DayPicker(selection: $selectedDate, place: place) {
                    // `now`, not `.now`, so Today follows the debug drawer's clock.
                    selectedDate = now
                    onToday()
                }
                if let day {
                    phases(of: day)
                    sun(of: day)
                    weather(on: day)
                }
            }
            .padding(.bottom)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .clipShape(shape)
        // Clear glass, with primary text, like the popovers: the sky shows through, and
        // gray or tinted text would wash out over daylight.
        .glassEffect(.regular, in: shape)
        // `DayPicker`'s cap, which the rest of the panel's text follows at the same width.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Day details")
    }

    // MARK: Sections

    private func phases(of day: SolarDay) -> some View {
        let current = day.segment(at: now)?.id
        return section("Phases") {
            ForEach(day.segments) { segment in
                let isCurrent = segment.id == current
                let range = day.rangeText(of: segment, startsLine: true)
                row(to: segment.midpoint, isCurrent: isCurrent, tint: segment.phase.color) {
                    Circle()
                        .fill(segment.phase.color)
                        // Keeps night's swatch visible on dark glass.
                        .strokeBorder(.primary.opacity(0.25), lineWidth: 0.5)
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                } content: {
                    Text(segment.phase.title)
                        .font(.subheadline.weight(.semibold))
                    Text([range, segment.durationText().map(unbroken)].compactMap(\.self).joined(separator: " · "))
                        .font(.footnote.monospacedDigit())
                }
                .accessibilityLabel([segment.phase.title, range, segment.durationText(width: .wide)].compactMap(\.self).joined(separator: ", "))
                .accessibilityHint("Scrolls the timeline to this phase")
            }
        }
    }

    @ViewBuilder
    private func sun(of day: SolarDay) -> some View {
        let events = day.events.sorted { $0.date < $1.date }
        if !events.isEmpty {
            section("Sun") {
                ForEach(events) { event in
                    row(to: event.date) {
                        icon(event.symbolName)
                    } content: {
                        Text(event.title)
                            .font(.subheadline.weight(.semibold))
                        Text(day.timeText(event.date))
                            .font(.footnote.monospacedDigit())
                    }
                    .accessibilityLabel("\(event.title), \(day.timeText(event.date))")
                    .accessibilityHint("Scrolls the timeline to it")
                }
            }
        }
    }

    /// Ends with the Apple Weather mark, since App Review looks for it wherever weather shows,
    /// and this list shows it apart from the timeline's sources button.
    @ViewBuilder
    private func weather(on day: SolarDay) -> some View {
        let spells = weather.filter { $0.span(within: day) != nil }
        if !spells.isEmpty {
            section("Weather") {
                ForEach(spells) { spell in
                    let range = day.rangeText(spell.interval, span: spell.span(within: day) ?? .range, startsLine: true)
                    row(to: spell.start(on: day)) {
                        icon(spell.condition.symbolName(inDaylight: spell.startsInDaylight(on: day)))
                    } content: {
                        Text(spell.title)
                            .font(.subheadline.weight(.semibold))
                        Text([range, spell.summary].compactMap(\.self).joined(separator: " · "))
                            .font(.footnote.monospacedDigit())
                    }
                    .accessibilityLabel(spell.description(range: range))
                    .accessibilityHint("Scrolls the timeline to this spell")
                }
                AppleWeatherCredit()
                    .font(.footnote)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: Pieces

    private func section<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            rows()
        }
    }

    /// A row that scrolls the timeline to `date`. The phase under way now is tinted with its color.
    private func row<Leading: View, Content: View>(
        to date: Date,
        isCurrent: Bool = false,
        tint: Color = .clear,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            onFocus(date)
        } label: {
            HStack(spacing: 12) {
                leading()
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    content()
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Text("Now")
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tint.opacity(0.25))
                }
            }
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .padding(.horizontal, 8)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityValue(isCurrent ? Text("Now") : Text(verbatim: ""))
    }

    /// Keeps a duration like "1 hr, 4 min" on one line, so large text wraps at the dot before it.
    private func unbroken(_ text: String) -> String {
        text.replacing(" ", with: "\u{00A0}")
    }

    /// In the text's color rather than multicolor, whose yellow sun vanishes on glass over daylight.
    private func icon(_ symbolName: String) -> some View {
        Image(systemName: symbolName)
            .symbolRenderingMode(.hierarchical)
            .font(.body)
            .accessibilityHidden(true)
    }
}

#Preview("Loaded") {
    @Previewable @State var selectedDate = Date.now
    let day = SolarDay.mock(for: selectedDate)
    ZStack(alignment: .trailing) {
        SkyGradient(day: day)
            .ignoresSafeArea()
        DayPanel(
            day: day,
            now: .now,
            selectedDate: $selectedDate,
            place: MockPlaceProvider.sanFrancisco,
            weather: WeatherSpell.mock(for: selectedDate),
            onToday: {},
            onFocus: { _ in }
        )
        .padding(DayPanel.margin)
    }
}

#Preview("Failed") {
    @Previewable @State var selectedDate = Date.now
    ZStack(alignment: .trailing) {
        DayPhase.night.color
            .ignoresSafeArea()
        DayPanel(
            day: nil,
            now: .now,
            selectedDate: $selectedDate,
            place: TimeZonePlaceProvider().lastKnownPlace(in: .current),
            onToday: {},
            onFocus: { _ in }
        )
        .padding(DayPanel.margin)
    }
}
