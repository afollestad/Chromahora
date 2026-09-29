//
//  MoonView.swift
//  Chromahora
//

import SwiftUI

/// The small widget for the night sky: the moon's phase and how much of it is lit, in large
/// type, and tonight's dark sky, the darkest night with the moon down.
struct MoonView: View {
    let entry: SkyEntry

    /// As the day's details give it, as in "31%".
    private static let percent = FloatingPointFormatStyle<Double>.Percent().precision(.fractionLength(0))

    var body: some View {
        WidgetContent(entry: entry) { content in
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetPlaceHeader(place: content.place, deviceName: content.deviceName)
                    moon((content.run.day(containing: entry.date) ?? content.run.days[0]).moon)
                    Spacer(minLength: 4)
                    darkSky(in: content.run)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 4)
                WidgetCredit(showsWeather: false)
            }
        }
    }

    @ViewBuilder
    private func moon(_ moon: SolarDay.Moon?) -> some View {
        HStack(spacing: 8) {
            MoonGlyph(phase: moon?.phase, illumination: moon?.illumination, size: 32, relativeTo: .largeTitle)
            if let lit = moon?.illumination?.formatted(Self.percent) {
                WidgetHero(lit)
                    .accessibilityLabel("\(lit) illuminated")
            }
        }
        Text(moon?.phase?.title ?? "Moon")
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    /// Tonight's dark sky, or why there's none. Nothing when a day can't place its moon.
    @ViewBuilder
    private func darkSky(in run: DayRun) -> some View {
        if let text = Self.darkSkyText(run.darkSky(at: entry.date), in: run) {
            Label(text, systemImage: "sparkles")
                .font(.footnote.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityLabel("Dark sky, \(text)")
        }
    }

    private static func darkSkyText(_ darkSky: DayRun.DarkSky?, in run: DayRun) -> String? {
        switch darkSky {
        case .stretch(let interval, let span): run.rangeText(interval, span: span, startsLine: true)
        case .neverDark: "Never fully dark"
        case .moonUp: "Moon up all night"
        case nil: nil
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: .now)
    VStack(spacing: 16) {
        ForEach([16, 23], id: \.self) { hour in
            let now = calendar.date(bySettingHour: hour, minute: 30, second: 0, of: day) ?? day
            let entry = SkyEntry(date: now, state: .loaded(.preview(at: now)))
            MoonView(entry: entry)
                .skyWidgetBackground(for: entry)
                .padding(16)
                .frame(width: 164, height: 164)
                .background(SkyBackground(entry: entry))
                .clipShape(.rect(cornerRadius: 24))
        }
    }
}
