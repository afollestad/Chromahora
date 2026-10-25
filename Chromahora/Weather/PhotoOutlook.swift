//
//  PhotoOutlook.swift
//  Chromahora
//

import Foundation

/// How promising a stretch of light looks for photographs. Named levels rather than a score,
/// since a cloud forecast hours out can't back a finer one.
nonisolated enum OutlookRating: Int, Comparable, CaseIterable, Sendable {
    case poor
    case fair
    case good
    case great
    case excellent

    var title: String {
        switch self {
        case .poor: "Poor"
        case .fair: "Fair"
        case .good: "Good"
        case .great: "Great"
        case .excellent: "Excellent"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// `steps` levels up, or down for a negative count, stopping at either end of the scale.
    func moved(by steps: Int) -> OutlookRating {
        Self(rawValue: min(max(rawValue + steps, 0), Self.allCases.count - 1)) ?? self
    }
}

/// A stretch of a day the outlook rates, and what it makes of the forecast over it.
nonisolated struct OutlookSession: Identifiable, Equatable, Sendable {
    enum Kind: Sendable {
        /// The dark sky before the day's noon, as `DayRun.noon(of:)` places it, or astronomical
        /// night where the moon is up through it or can't be placed: the small hours.
        case beforeDawn
        /// The morning's golden and blue hours, as `DayRun.ends(of:)` parts them.
        case morning
        /// The daylight, rated by how soft or harsh its light is.
        case daylight
        /// The evening's golden and blue hours.
        case evening
        /// The same ending after the day's noon: the evening's, or one that runs through noon, as
        /// in a polar night.
        case night

        var title: String {
            switch self {
            case .beforeDawn: "Before dawn"
            case .morning: "Morning"
            case .daylight: "Daylight"
            case .evening: "Evening"
            case .night: "Tonight"
            }
        }

        /// As the details mark sunrise, sunset and the dark sky.
        var symbolName: String {
            switch self {
            case .morning: "sunrise.fill"
            case .daylight: "sun.max.fill"
            case .evening: "sunset.fill"
            case .beforeDawn, .night: "sparkles"
            }
        }

        /// Whether it rates the dark sky, by how many stars show.
        var isNight: Bool {
            self == .beforeDawn || self == .night
        }
    }

    let kind: Kind
    /// What it rates, in time order, and never empty: the end's golden and blue hours, the
    /// daylight, or the dark sky on one side of noon.
    let intervals: [DateInterval]
    let rating: OutlookRating
    /// What led to the rating, the most telling first.
    let reasons: [String]
    /// The mean share of the sky covered over its hours, from 0 to 1.
    let cloudCover: Double

    /// A day's sessions never start together, and neither do two days'.
    var id: Date { start }

    var start: Date {
        intervals[0].start
    }

    var end: Date {
        intervals[intervals.count - 1].end
    }

    /// Where the timeline centers for it: the middle of its longest stretch, which in a morning
    /// or evening is usually the golden hour.
    var focusDate: Date {
        let longest = intervals.max { $0.duration < $1.duration } ?? intervals[0]
        return longest.start.addingTimeInterval(longest.duration / 2)
    }
}

/// Rates a day's light for photographs from the forecast's hours: its golden and blue hours by
/// the cloud the low sun can light, its daylight by how soft the light is, and its night by how
/// much of the sky shows. Each rating starts from the cloud, moves a level for each thing that
/// helps or hinders, and stops at a cap where one thing rules out the rest.
///
/// Kept apart from `SolarDay`, which stays free of weather, since forecasts change and fail
/// while sun times don't.
nonisolated enum PhotoOutlook {
    /// Mid or high cloud over 30% to 70% of the sky gives the low sun something to light from
    /// below, with gaps for it to shine through: the band sunset forecasters rate most colorful.
    static let colorCloud = 0.3...0.7
    /// Four eighths, half the sky, past which cloud hides more stars than it shows.
    static let halfSky = 0.5
    /// The WMO calls it fog below 1 km.
    static let fogVisibility = 1_000.0
    /// Below 5 km, the WMO's mist and haze, distant detail softens and color dulls.
    static let hazeVisibility = 5_000.0
    /// Up to Beaufort 1, light air, ripples are too slight to break a reflection.
    static let calmWind = 1.5
    /// From Beaufort 5, a fresh breeze, hair, clothing, branches and water won't hold still, and
    /// a tripod shakes through a long exposure.
    static let windyWind = 8.0
    /// A shower that clears within this long of the low sun leaves broken cloud and washed air.
    static let clearingLookback: TimeInterval = 3 * 60 * 60
    /// Overlaps summed in floating point can fall a hair short of the interval they cover.
    static let coverageTolerance: TimeInterval = 1

    /// Where the moon is through the night a session rates.
    enum NightSky: Sendable {
        /// The stretches are dark sky, with the moon down.
        case dark
        /// The moon is up through all of astronomical night.
        case moonUp
        /// The day can't place the moon, so astronomical night is rated without it.
        case moonUnknown
    }

    /// `day`'s sessions that `hours` cover, in the order of `OutlookSession.Kind`. `run` merges
    /// golden and blue hours across midnight, so an evening blue hour that runs into tomorrow
    /// reads whole when `run` holds tomorrow; `day` alone ends it at midnight. `hours` come in
    /// time order, as a forecast gives them.
    static func sessions(on day: SolarDay, in run: DayRun? = nil, hours: [SkyHour]) -> [OutlookSession] {
        stretches(on: day, in: run ?? DayRun(day)).compactMap { rate($0, hours: hours) }
    }

    /// The morning or evening session that `magicHour`, a golden or blue hour of `run`, belongs
    /// to. Nil for one under way as `run` starts, which began the evening before, and where the
    /// forecast misses its session.
    static func session(for magicHour: DaySegment, in run: DayRun, hours: [SkyHour]) -> OutlookSession? {
        guard let day = run.day(containing: magicHour.interval.start) else {
            return nil
        }
        let stretch = stretches(on: day, in: run).first { stretch in
            (stretch.kind == .morning || stretch.kind == .evening)
                && stretch.intervals.contains { $0.start == magicHour.interval.start }
        }
        return stretch.flatMap { rate($0, hours: hours) }
    }

    /// The session each of `day`'s phases carries on the timeline, keyed by the phase's start:
    /// every golden and blue hour its end's, which rates them together, so neither label reads as
    /// the only one rated; every daylight; and every night holding a dark sky the outlook rates.
    /// A night that holds both, as a polar night does, carries tonight's.
    static func labelSessions(on day: SolarDay, in run: DayRun? = nil, hours: [SkyHour]) -> [Date: OutlookSession] {
        let run = run ?? DayRun(day)
        let ends = run.ends(of: day)
        var labeled: [Date: OutlookSession] = [:]
        for session in sessions(on: day, in: run, hours: hours) {
            let segments = switch session.kind {
            case .morning: ends.morning.magicHours
            case .evening: ends.evening.magicHours
            case .daylight: day.segments.filter { $0.phase == .daylight }
            case .beforeDawn, .night:
                day.segments.filter { segment in
                    segment.phase == .night && session.intervals.contains { $0.start < segment.interval.end && $0.end > segment.interval.start }
                }
            }
            for segment in segments {
                labeled[segment.interval.start] = session
            }
        }
        return labeled
    }

    // MARK: Sessions

    /// What a session rates, before the forecast is read.
    private struct Stretch {
        let kind: OutlookSession.Kind
        let intervals: [DateInterval]
        var night = NightSky.dark
    }

    private static func stretches(on day: SolarDay, in run: DayRun) -> [Stretch] {
        let ends = run.ends(of: day)
        let nights = Self.nights(on: day)
        return [
            nights.beforeDawn,
            Stretch(kind: .morning, intervals: ends.morning.magicHours.map(\.interval)),
            Stretch(kind: .daylight, intervals: day.segments.filter { $0.phase == .daylight }.map(\.interval)),
            Stretch(kind: .evening, intervals: ends.evening.magicHours.map(\.interval)),
            nights.tonight
        ]
        .compactMap(\.self)
        .filter { !$0.intervals.isEmpty }
    }

    /// The dark sky the details list, or astronomical night where the moon is up through it or
    /// can't be placed, parted at the day's noon, since the small hours and the evening are
    /// different nights to go out in. Neither where the day never gets that dark.
    private static func nights(on day: SolarDay) -> (beforeDawn: Stretch?, tonight: Stretch?) {
        guard !day.astronomicalNight.isEmpty else {
            return (nil, nil)
        }
        let (intervals, night): ([DateInterval], NightSky) = switch day.darkSky {
        case nil: (day.astronomicalNight, .moonUnknown)
        case let darkSky? where darkSky.isEmpty: (day.astronomicalNight, .moonUp)
        case let darkSky?: (darkSky, .dark)
        }
        // Parted by where each stretch ends, so one that runs through noon, as in a polar night, is tonight's.
        let noon = DayRun.noon(of: day)
        return (
            Stretch(kind: .beforeDawn, intervals: intervals.filter { $0.end <= noon }, night: night),
            Stretch(kind: .night, intervals: intervals.filter { $0.end > noon }, night: night)
        )
    }

    private static func rate(_ stretch: Stretch, hours: [SkyHour]) -> OutlookSession? {
        guard let readings = Readings(over: stretch.intervals, hours: hours) else {
            return nil
        }
        let assessment = assess(stretch.kind, readings, night: stretch.night)
        return OutlookSession(
            kind: stretch.kind,
            intervals: stretch.intervals,
            rating: assessment.rating,
            reasons: assessment.reasons,
            cloudCover: readings.cloudCover
        )
    }

    // MARK: Readings

    /// A session's forecast, each hour weighted by how much of the session it covers. The
    /// defaults are a clear sky in a light breeze, neither calm nor windy, so a test names only
    /// what it changes.
    struct Readings: Equatable, Sendable {
        var lowCloud = 0.0
        var midCloud = 0.0
        var highCloud = 0.0
        var cloudCover = 0.0
        /// Each hour's thicker layer above the low cloud: what the low sun can light from below.
        var upperCloud = 0.0
        var visibility = 20_000.0
        var windSpeed = 3.0
        var peakUV = 0
        /// The likeliest precipitation over the session, if any has a type.
        var precipitation: SkyCondition?
        var precipitationChance = 0.0
        /// The likeliest precipitation within `clearingLookback` before the session starts.
        var precipitationBefore: SkyCondition?
        var chanceBefore = 0.0
    }

    // MARK: Assessment

    /// What a finding does to the rating, which orders the reasons.
    private enum Effect {
        case raises
        case neutral
        case lowers
    }

    /// One finding about the readings: what it says, and how it moves or caps the rating.
    private struct Reason {
        /// What the finding does to a photograph, as in "Little cloud to catch color", not just
        /// what the sky holds, since a clear sky alone can't say why it earns Good one session
        /// and Excellent another.
        let text: String
        let effect: Effect
        var step = 0
        /// The highest rating the finding allows.
        var cap: OutlookRating?
    }

    private static let percent = FloatingPointFormatStyle<Double>.Percent().precision(.fractionLength(0))

    /// The rating `readings` earn for a session of `kind`, and every reason behind it, those
    /// that lift a good rating, or sink a poor one, first. The base comes from the cloud, then
    /// every step adds up before the rating stops at either end of the scale, then the lowest cap holds it.
    static func assess(
        _ kind: OutlookSession.Kind, _ readings: Readings, night: NightSky = .dark
    ) -> (rating: OutlookRating, reasons: [String]) {
        let base = base(for: kind, readings)
        let findings = caps(for: kind, readings, night: night) + base.reasons + steps(for: kind, readings)
        let stepped = base.rating.moved(by: findings.map(\.step).reduce(0, +))
        let rating = findings.compactMap(\.cap).reduce(stepped, min)
        let order: [Effect] = rating >= .good ? [.raises, .neutral, .lowers] : [.lowers, .neutral, .raises]
        return (rating, order.flatMap { effect in findings.filter { $0.effect == effect }.map(\.text) })
    }

    private static func base(for kind: OutlookSession.Kind, _ readings: Readings) -> (rating: OutlookRating, reasons: [Reason]) {
        switch kind {
        case .morning, .evening: magicHourBase(readings)
        case .daylight: daylightBase(readings)
        case .beforeDawn, .night: nightBase(readings)
        }
    }

    /// Color comes from the low sun lighting mid or high cloud from below, which a deck of low
    /// cloud shuts out, and too much upper cloud blocks. A clear sky still gives warm light.
    private static func magicHourBase(_ readings: Readings) -> (rating: OutlookRating, reasons: [Reason]) {
        guard readings.lowCloud < WeatherHour.cloudyCover else {
            return (.poor, [Reason(text: "Low cloud blocks the sun", effect: .lowers)])
        }
        let isHigh = readings.highCloud >= readings.midCloud
        let littleLowCloud = readings.lowCloud <= WeatherHour.clearCover
        let someLowCloud = Reason(text: "Low cloud may block the sun", effect: .lowers)
        if readings.upperCloud < colorCloud.lowerBound {
            return littleLowCloud ? (.good, [Reason(text: "Little cloud to catch color", effect: .neutral)]) : (.fair, [someLowCloud])
        }
        if colorCloud.contains(readings.upperCloud) {
            let catchesColor = Reason(text: isHigh ? "High cloud to catch color" : "Mid cloud to catch color", effect: .raises)
            return littleLowCloud ? (.excellent, [catchesColor]) : (.good, [catchesColor, someLowCloud])
        }
        let thick = Reason(text: isHigh ? "Thick high cloud may mute color" : "Thick mid cloud may mute color", effect: .lowers)
        return littleLowCloud ? (.fair, [thick]) : (.poor, [thick, someLowCloud])
    }

    /// Cloud over most of the sky softens daylight for portraits and close work, while UV takes
    /// the harsh, clear light down a step or two.
    private static func daylightBase(_ readings: Readings) -> (rating: OutlookRating, reasons: [Reason]) {
        if readings.cloudCover >= WeatherHour.cloudyCover {
            return (.great, [Reason(text: "Soft light under cloud", effect: .raises)])
        }
        let text = readings.cloudCover <= WeatherHour.clearCover ? "Little cloud to soften the light" : "Broken cloud, uneven light"
        return (.good, [Reason(text: text, effect: .neutral)])
    }

    private static func nightBase(_ readings: Readings) -> (rating: OutlookRating, reasons: [Reason]) {
        switch readings.cloudCover {
        case ...WeatherHour.clearCover: (.excellent, [Reason(text: "Clear sky for stars", effect: .raises)])
        case ...halfSky: (.good, [Reason(text: "Cloud hides some stars", effect: .neutral)])
        case ..<WeatherHour.cloudyCover: (.fair, [Reason(text: "Cloud hides most stars", effect: .lowers)])
        default: (.poor, [Reason(text: "Cloud hides the stars", effect: .lowers)])
        }
    }

    /// What holds a rating down whatever else is true: fog, which hides the sky and at night
    /// the stars, precipitation more likely than not, and a moon up through the whole night.
    private static func caps(for kind: OutlookSession.Kind, _ readings: Readings, night: NightSky) -> [Reason] {
        var caps: [Reason] = []
        if readings.visibility < fogVisibility {
            caps.append(kind.isNight
                ? Reason(text: "Fog hides the stars", effect: .lowers, cap: .poor)
                : Reason(text: "Fog hides the sky", effect: .lowers, cap: .fair))
        }
        if let chance = chanceText(readings), readings.precipitationChance >= WeatherSpell.likelyChance {
            caps.append(Reason(text: chance, effect: .lowers, step: -1, cap: .fair))
        }
        if kind.isNight, night == .moonUp {
            caps.append(Reason(text: "Moonlight washes out stars", effect: .lowers, cap: .fair))
        }
        return caps
    }

    /// What moves a rating a level or two. Calm air only earns a mention: it makes reflections,
    /// but no better light.
    private static func steps(for kind: OutlookSession.Kind, _ readings: Readings) -> [Reason] {
        let isMagicHour = kind == .morning || kind == .evening
        var steps: [Reason] = []
        if isMagicHour, let earlier = readings.precipitationBefore, readings.chanceBefore >= WeatherSpell.likelyChance,
           readings.precipitationChance < WeatherHour.possibleChance {
            steps.append(Reason(text: "Clean air after \(earlier.title.lowercased())", effect: .raises, step: 1))
        }
        if isMagicHour, readings.windSpeed <= calmWind {
            steps.append(Reason(text: "Calm air for reflections", effect: .neutral))
        }
        if kind == .daylight, let harshness = uvStep(readings.peakUV) {
            steps.append(Reason(text: "Harsh light, UV \(readings.peakUV)", effect: .lowers, step: harshness))
        }
        if let chance = chanceText(readings), readings.precipitationChance >= WeatherHour.possibleChance,
           readings.precipitationChance < WeatherSpell.likelyChance {
            steps.append(Reason(text: chance, effect: .lowers, step: -1))
        }
        if readings.visibility >= fogVisibility, readings.visibility < hazeVisibility {
            steps.append(Reason(text: kind.isNight ? "Haze dims the stars" : "Haze dulls color and detail", effect: .lowers, step: -1))
        }
        if readings.windSpeed >= windyWind {
            let text = kind.isNight ? "Wind shakes tripods and trees" : "Wind moves hair, trees and water"
            steps.append(Reason(text: text, effect: .lowers, step: -1))
        }
        return steps
    }

    /// From High on the WHO's scale, 6, the sun is high in a clear sky and its light hard, and
    /// from Very high, 8, harder still.
    private static func uvStep(_ uvIndex: Int) -> Int? {
        switch SkyHour.UVCategory(uvIndex: uvIndex) {
        case .low, .moderate: nil
        case .high: -1
        case .veryHigh, .extreme: -2
        }
    }

    /// As in "40% chance of rain", or nil without a type, which no condition shows.
    private static func chanceText(_ readings: Readings) -> String? {
        readings.precipitation.map { "\(readings.precipitationChance.formatted(percent)) chance of \($0.title.lowercased())" }
    }
}

nonisolated extension PhotoOutlook.Readings {
    /// The readings over `intervals`, or nil unless `hours`, in time order, cover every one.
    init?(over intervals: [DateInterval], hours: [SkyHour]) {
        var weighted: [(hour: SkyHour, weight: TimeInterval)] = []
        for interval in intervals {
            let overlaps = hours.compactMap { hour in
                Self.overlap(of: hour, with: interval).map { (hour: hour, weight: $0) }
            }
            guard overlaps.map(\.weight).reduce(0, +) >= interval.duration - PhotoOutlook.coverageTolerance else {
                return nil
            }
            weighted += overlaps
        }
        let total = weighted.map(\.weight).reduce(0, +)
        guard let start = intervals.first?.start, total > 0 else {
            return nil
        }
        func mean(_ reading: (SkyHour) -> Double) -> Double {
            weighted.map { reading($0.hour) * $0.weight }.reduce(0, +) / total
        }
        let lookback = DateInterval(start: start.addingTimeInterval(-PhotoOutlook.clearingLookback), end: start)
        let likeliest = Self.likeliest(weighted.map(\.hour))
        let likeliestBefore = Self.likeliest(hours.filter { Self.overlap(of: $0, with: lookback) != nil })
        self.init(
            lowCloud: mean(\.lowCloud),
            midCloud: mean(\.midCloud),
            highCloud: mean(\.highCloud),
            cloudCover: mean(\.cloudCover),
            upperCloud: mean { max($0.midCloud, $0.highCloud) },
            visibility: mean(\.visibility),
            windSpeed: mean(\.windSpeed),
            peakUV: weighted.map(\.hour.uvIndex).max() ?? 0,
            precipitation: likeliest?.precipitation,
            precipitationChance: likeliest?.precipitationChance ?? 0,
            precipitationBefore: likeliestBefore?.precipitation,
            chanceBefore: likeliestBefore?.precipitationChance ?? 0
        )
    }

    /// How long `hour` shares with `interval`, or nil where they only touch or miss.
    private static func overlap(of hour: SkyHour, with interval: DateInterval) -> TimeInterval? {
        hour.interval.intersection(with: interval).map(\.duration).flatMap { $0 > 0 ? $0 : nil }
    }

    /// The hour with the likeliest precipitation of a known type, the earliest of equals.
    private static func likeliest(_ hours: [SkyHour]) -> SkyHour? {
        hours
            .filter { $0.precipitation?.isPrecipitation == true }
            .max { $0.precipitationChance < $1.precipitationChance }
    }
}
