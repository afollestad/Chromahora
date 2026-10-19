//
//  WeatherButton.swift
//  Chromahora
//

import SwiftUI

/// A weather spell's icon among the timeline's markers, which opens a popover describing
/// the spell, or a sheet on the watch, which has no popovers. VoiceOver reads the same
/// description as the button's label.
struct WeatherButton: View {
    let spell: WeatherSpell
    /// When the spell runs, as the timeline words it for the day.
    let range: String
    /// Whether the spell starts in daylight or golden hour, which shows a sun rather than a moon.
    let inDaylight: Bool
    /// The scheme of the sky behind the capsule, which the overlay picks for every label.
    /// Only the capsule takes it, so the popover keeps the system's.
    let scheme: ColorScheme
    /// Whether a sky spell names its cloud cover beside its icon, which says what the timeline's
    /// cloud band beside it measures.
    var showsCloudCover = false

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Self.glyph(for: spell, inDaylight: inDaylight, showsCloudCover: showsCloudCover)
                .glassEffect(.regular.interactive(), in: Capsule())
                .environment(\.colorScheme, scheme)
                // A taller target than the capsule, without widening what the overlay measures.
                .padding(.vertical, 10)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spell.description(range: range))
        #if os(iOS)
        .popover(isPresented: $isPresented, arrowEdge: .leading) {
            WeatherSpellDetails(spell: spell, range: range, inDaylight: inDaylight)
                .popoverPadding()
                // Stops growing at accessibility1, like the timeline's labels. Past it, the popover runs
                // out of room beside its marker and truncates the time range and the credit.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .popoverContent()
        }
        #else
        .sheet(isPresented: $isPresented) {
            ScrollView {
                WeatherSpellDetails(spell: spell, range: range, inDaylight: inDaylight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scenePadding(.horizontal)
            }
        }
        #endif
    }

    /// The icon padded to fill its capsule, which the overlay also cuts out of the lines behind it.
    /// The same font and padding as the overlay's text labels, so the capsule is as tall as
    /// theirs and marker spacing holds. With `showsCloudCover`, a clear or cloudy spell names its
    /// cover after the icon, as in "90% cloud", since a bare figure could be a chance of rain.
    /// Precipitation and fog name none, so their figures never read as cover.
    static func glyph(for spell: WeatherSpell, inDaylight: Bool, showsCloudCover: Bool = false) -> some View {
        let icon = Image(systemName: spell.condition.symbolName(inDaylight: inDaylight))
        let cover = showsCloudCover ? cloudCover(of: spell) : nil
        return Group {
            if let cover {
                Text("\(icon) \(cover.formatted(Self.percent)) cloud")
                    .monospacedDigit()
            } else {
                Text("\(icon)")
            }
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, cover == nil ? 7 : 10)
        .padding(.vertical, 5)
    }

    private static let percent = FloatingPointFormatStyle<Double>.Percent().precision(.fractionLength(0))

    /// The share of the sky a clear or cloudy spell covers, or nil for precipitation and fog.
    private static func cloudCover(of spell: WeatherSpell) -> Double? {
        switch spell.condition {
        case .clear, .partlyCloudy, .cloudy: spell.cloudCover
        case .fog, .rain, .snow, .sleet, .hail, .mixed: nil
        }
    }
}

#Preview {
    let spells = WeatherSpell.mock()
    VStack {
        WeatherButton(spell: spells[3], range: "3:00 – 5:00 PM", inDaylight: true, scheme: .light)
        WeatherButton(spell: spells[2], range: "9:00 AM – 3:00 PM", inDaylight: true, scheme: .light, showsCloudCover: true)
    }
    .padding()
    .background(DayPhase.daylight.color)
}
