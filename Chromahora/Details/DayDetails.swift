//
//  DayDetails.swift
//  Chromahora
//

import SwiftUI

/// The day as a list: its phases, the sun, the moon, and the weather with the day's light and
/// sky readings. The day panel shows it under its calendar, and without room for the panel it's
/// the page beside the timeline. Tapping a row with a time scrolls the timeline to it, and each
/// row's info button says what it reads and how a photographer uses it.
struct DayDetails: View {
    let day: SolarDay
    let now: Date
    /// The forecast's spells, of any day. Those reaching this one are listed.
    var weather: [WeatherSpell] = []
    /// The forecast's hours, of any day, which the UV and sky rows read.
    var hours: [SkyHour] = []
    /// Whether the weather ends with the Apple Weather mark and its legal link. The day panel
    /// shows them apart from the sources button under the timeline, while the page beside the
    /// timeline sits right above the button, which carries both, as it does for the timeline.
    var showsWeatherCredit = true
    /// Scrolls the timeline to a time on the day.
    let onFocus: (Date) -> Void

    /// A crossing of the horizon other than the sun's, which isn't marked on the timeline.
    private struct Crossing: Identifiable {
        let topic: DetailTopic
        let title: String
        let symbolName: String
        let date: Date

        var id: String { title }
    }

    /// The forecast hour holding a sunrise or sunset.
    private struct HorizonSky: Identifiable {
        let title: String
        let event: Date
        let hour: SkyHour

        var id: String { title }
    }

    private static let percent = FloatingPointFormatStyle<Double>.Percent().precision(.fractionLength(0))

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            phases
            sun
            moon
            weatherAndSky
        }
    }

    // MARK: Sections

    private var phases: some View {
        let current = day.segment(at: now)?.id
        return section("Phases") {
            ForEach(day.segments) { segment in
                let range = day.rangeText(of: segment, startsLine: true)
                let reading = DetailReading(
                    topic: DetailTopic(segment.phase),
                    title: segment.phase.title,
                    details: [range, segment.durationText().map(unbroken)],
                    label: [segment.phase.title, range, segment.durationText(width: .wide)].compactMap(\.self).joined(separator: ", ")
                )
                row(
                    reading,
                    to: segment.midpoint,
                    hint: "Scrolls the timeline to this phase",
                    isCurrent: segment.id == current,
                    tint: segment.phase.color
                ) {
                    Circle()
                        .fill(segment.phase.color)
                        // Keeps night's swatch visible on dark glass.
                        .strokeBorder(.primary.opacity(0.25), lineWidth: 0.5)
                        .frame(width: 14, height: 14)
                }
            }
        }
    }

    @ViewBuilder
    private var sun: some View {
        let events = day.events.sorted { $0.date < $1.date }
        if !events.isEmpty {
            section("Sun") {
                ForEach(events) { event in
                    let time = day.timeText(event.date)
                    let reading = DetailReading(topic: DetailTopic(event.kind), title: event.title, details: [time], label: "\(event.title), \(time)")
                    row(reading, to: event.date) {
                        icon(event.symbolName)
                    }
                }
            }
        }
    }

    /// The moon's phase, its rise and set, and the dark sky it leaves, as far as the day knows them.
    @ViewBuilder
    private var moon: some View {
        let moon = day.moon
        let showsPhase = moon?.phase != nil || moon?.illumination != nil
        let crossings = [
            moon?.rise.map { Crossing(topic: .moonrise, title: "Moonrise", symbolName: "moonrise.fill", date: $0) },
            moon?.set.map { Crossing(topic: .moonset, title: "Moonset", symbolName: "moonset.fill", date: $0) }
        ]
        .compactMap(\.self)
        .sorted { $0.date < $1.date }
        let darkSky = day.darkSky
        if showsPhase || !crossings.isEmpty || darkSky != nil {
            section("Moon") {
                if let moon, showsPhase {
                    phase(of: moon)
                }
                ForEach(crossings) { crossing in
                    let time = day.timeText(crossing.date)
                    let reading = DetailReading(topic: crossing.topic, title: crossing.title, details: [time], label: "\(crossing.title), \(time)")
                    row(reading, to: crossing.date) {
                        icon(crossing.symbolName)
                    }
                }
                if let darkSky {
                    self.darkSky(darkSky)
                }
            }
        }
    }

    /// Ends with the Apple Weather mark where `showsWeatherCredit` asks, since App Review looks
    /// for it wherever weather shows.
    @ViewBuilder
    private var weatherAndSky: some View {
        let spells = weather.filter { $0.span(within: day) != nil }
        let peak = SkyHour.peakUV(on: day, in: hours)
        let skies = day.events.sorted { $0.date < $1.date }.compactMap { event in
            SkyHour.hour(containing: event.date, in: hours).map { HorizonSky(title: "\(event.title) sky", event: event.date, hour: $0) }
        }
        if !spells.isEmpty || peak != nil || !skies.isEmpty {
            section("Weather") {
                ForEach(spells) { spell in
                    let range = day.rangeText(spell.interval, span: spell.span(within: day) ?? .range, startsLine: true)
                    let reading = DetailReading(
                        topic: DetailTopic(spell.condition),
                        title: spell.title,
                        details: [range, spell.summary],
                        label: spell.description(range: range)
                    )
                    row(reading, to: spell.start(on: day), hint: "Scrolls the timeline to this spell") {
                        icon(spell.condition.symbolName(inDaylight: spell.startsInDaylight(on: day)))
                    }
                }
                if let peak {
                    uvIndex(peaking: peak)
                }
                ForEach(skies) { sky in
                    horizon(sky)
                }
                if showsWeatherCredit {
                    AppleWeatherCredit()
                        .font(.footnote)
                        .padding(.horizontal, DetailMetrics.contentInset)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: Rows

    private func phase(of moon: SolarDay.Moon) -> some View {
        let name = moon.phase?.title ?? "Moon"
        let lit = moon.illumination.map { "\($0.formatted(Self.percent)) illuminated" }
        let reading = DetailReading(topic: .moonPhase, title: name, details: [lit], label: [name, lit].compactMap(\.self).joined(separator: ", "))
        return row(reading, to: nil) {
            MoonGlyph(phase: moon.phase, illumination: moon.illumination, size: 18, relativeTo: .body)
        }
    }

    /// Each stretch of dark sky, or a row saying there's none, since that's worth knowing too.
    @ViewBuilder
    private func darkSky(_ windows: [DateInterval]) -> some View {
        if windows.isEmpty {
            let reason = day.astronomicalNight.isEmpty ? "None, as it never gets fully dark" : "None, with the moon up"
            row(DetailReading(topic: .darkSky, title: "Dark sky", details: [reason], label: "Dark sky, \(reason)"), to: nil) {
                icon("sparkles")
            }
        } else {
            ForEach(windows, id: \.start) { window in
                let span = day.span(of: window)
                let range = day.rangeText(window, span: span, startsLine: true)
                let duration = span == .range ? window.duration : nil
                let reading = DetailReading(
                    topic: .darkSky,
                    title: "Dark sky",
                    details: [range, duration.map { unbroken(DaySegment.durationText($0)) }],
                    label: ["Dark sky", range, duration.map { DaySegment.durationText($0, width: .wide) }].compactMap(\.self).joined(separator: ", ")
                )
                row(reading, to: window.start.addingTimeInterval(window.duration / 2)) {
                    icon("sparkles")
                }
            }
        }
    }

    private func uvIndex(peaking peak: SkyHour) -> some View {
        let date = max(peak.date, day.dayStart)
        let time = day.timeText(date)
        let category = peak.uvCategory.title.lowercased()
        let reading = DetailReading(
            topic: .uvIndex,
            title: "UV index",
            details: ["Peak \(peak.uvIndex), \(category)", time],
            label: "UV index, peaks at \(peak.uvIndex), \(category), at \(time)"
        )
        return row(reading, to: date) {
            icon("sun.max.fill")
        }
    }

    private func horizon(_ sky: HorizonSky) -> some View {
        let hour = sky.hour
        let clouds = [("low", hour.lowCloud), ("mid", hour.midCloud), ("high", hour.highCloud)]
            .map { "\($0) \($1.formatted(Self.percent))" }
            .joined(separator: ", ")
        // Without "cloud", so the layers fit a line beside the title; the info button says what they are.
        let reading = DetailReading(
            topic: .horizonSky,
            title: sky.title,
            details: [clouds.prefix(1).uppercased() + clouds.dropFirst(), "Visibility \(visibility(of: hour, width: .abbreviated))"],
            label: "\(sky.title), cloud \(clouds), visibility \(visibility(of: hour, width: .wide))"
        )
        return row(reading, to: sky.event) {
            icon("cloud.sun.fill")
        }
    }

    // MARK: Pieces

    private func section<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, DetailMetrics.contentInset)
                .padding(.bottom, 4)
            rows()
        }
    }

    /// A row that scrolls the timeline to `date`, when it has one, and tints the phase under way now.
    private func row<Leading: View>(
        _ reading: DetailReading,
        to date: Date?,
        hint: String = "Scrolls the timeline to it",
        isCurrent: Bool = false,
        tint: Color = .clear,
        @ViewBuilder leading: () -> Leading
    ) -> some View {
        DetailRow(reading: reading, date: date, hint: hint, isCurrent: isCurrent, tint: tint, onFocus: onFocus, leading: leading())
    }

    /// Keeps a duration like "1 hr, 4 min" on one line, so large text wraps before it rather than inside it.
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

    /// In the reader's units, to two significant digits, as in "15 mi".
    private func visibility(of hour: SkyHour, width: Measurement<UnitLength>.FormatStyle.UnitWidth) -> String {
        Measurement(value: hour.visibility, unit: UnitLength.meters)
            .formatted(.measurement(width: width, usage: .road, numberFormatStyle: .number.precision(.significantDigits(1...2))))
    }
}

#Preview {
    let day = SolarDay.mock()
    ScrollView {
        DayDetails(day: day, now: .now, weather: WeatherSpell.mock(), hours: SkyHour.mock()) { _ in }
    }
    .background(DayPhase.night.color)
}
