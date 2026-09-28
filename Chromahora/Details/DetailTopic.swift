//
//  DetailTopic.swift
//  Chromahora
//

import Foundation

/// What a row of the day's details reads, which its info button explains: what the reading
/// is, and how a photographer puts it to use.
nonisolated enum DetailTopic: Sendable {
    case night
    case blueHour
    case goldenHour
    case daylight
    case sunrise
    case sunset
    case clear
    case partlyCloudy
    case cloudy
    case fog
    case precipitation
    case uvIndex
    case horizonSky
    case moonPhase
    case moonrise
    case moonset
    case darkSky

    init(_ phase: DayPhase) {
        self = switch phase {
        case .night: .night
        case .blueHour: .blueHour
        case .goldenHour: .goldenHour
        case .daylight: .daylight
        }
    }

    init(_ event: SolarEvent.Kind) {
        self = switch event {
        case .sunrise: .sunrise
        case .sunset: .sunset
        }
    }

    init(_ condition: SkyCondition) {
        self = switch condition {
        case .clear: .clear
        case .partlyCloudy: .partlyCloudy
        case .cloudy: .cloudy
        case .fog: .fog
        case .rain, .snow, .sleet, .hail, .mixed: .precipitation
        }
    }

    var title: String {
        switch self {
        case .night: DayPhase.night.title
        case .blueHour: DayPhase.blueHour.title
        case .goldenHour: DayPhase.goldenHour.title
        case .daylight: DayPhase.daylight.title
        case .sunrise: "Sunrise"
        case .sunset: "Sunset"
        case .clear: SkyCondition.clear.title
        case .partlyCloudy: SkyCondition.partlyCloudy.title
        case .cloudy: SkyCondition.cloudy.title
        case .fog: SkyCondition.fog.title
        case .precipitation: "Rain and snow"
        case .uvIndex: "UV index"
        case .horizonSky: "Sunrise and sunset sky"
        case .moonPhase: "Moon phase"
        case .moonrise: "Moonrise"
        case .moonset: "Moonset"
        case .darkSky: "Dark sky"
        }
    }

    /// What the reading is. The phases' angles are `DayPhase.band(forAltitude:)`'s, and the
    /// cloud shares `WeatherHour`'s, which a spell only roughly keeps once it folds short runs in.
    var meaning: String {
        switch self {
        case .night:
            "The sun is more than 6° below the horizon. The sky's color is gone, leaving the moon, the stars and artificial light."
        case .blueHour:
            "The sun is 4° to 6° below the horizon, and light scattered from beyond it turns the sky a deep, even blue."
        case .goldenHour:
            "The sun is within a few degrees of the horizon, from 4° below it to 6° above, and its light is low, warm and soft."
        case .daylight:
            "The sun is more than 6° above the horizon, and its light grows whiter and harsher as it climbs."
        case .sunrise:
            "The moment the top of the sun clears the horizon, partway through the morning's golden hour."
        case .sunset:
            "The moment the top of the sun drops below the horizon, partway through the evening's golden hour."
        case .clear:
            "Cloud covers about a quarter of the sky or less for much of the stretch."
        case .partlyCloudy:
            "Cloud covers roughly a quarter to three quarters of the sky for much of the stretch."
        case .cloudy:
            "Cloud covers about three quarters of the sky or more for much of the stretch."
        case .fog:
            "Cloud at ground level, cutting how far you can see."
        case .precipitation:
            "Rain, snow, sleet or hail, shown from a 30% chance. Below even odds, it reads as a chance of it."
        case .uvIndex:
            """
            The strength of the sun's ultraviolet light, from 0 at night to 11 and up. It measures sunburn risk rather \
            than brightness, but it climbs with the sun and falls as cloud thickens.
            """
        case .horizonSky:
            "How much of the sky low, middle and high cloud covers in the hour of sunrise or sunset, and how far you can see."
        case .moonPhase:
            "How much of the moon's face the sun lights. It waxes from new to full and wanes back over about 29.5 days."
        case .moonrise:
            "When the moon clears the horizon. It rises about 50 minutes later each day, so some days have none."
        case .moonset:
            "When the moon sinks below the horizon. Like moonrise, it comes about 50 minutes later each day."
        case .darkSky:
            "Astronomical night, with the sun more than 18° below the horizon, while the moon is down. The sky gets no darker."
        }
    }

    var photographyTip: String {
        switch self {
        case .night:
            "Bring a tripod for long exposures: star trails, light trails and lit cityscapes. For the faintest stars, wait for dark sky."
        case .blueHour:
            "Balance the blue with street and window lights for cityscapes. It lasts minutes, so set up early and expose on a tripod."
        case .goldenHour:
            """
            Side and back light bring out texture, long shadows and rim light on portraits. Face the sun for glow and \
            flare, or turn away for warm, even color.
            """
        case .daylight:
            """
            Light from high overhead casts short, hard shadows. Work in open shade or with a diffuser, use a polarizer for \
            deeper skies and water, or scout for later.
            """
        case .sunrise:
            """
            Arrive in blue hour to set up, since the richest color often comes just before the sun appears. Plan where it \
            rises against your subject.
            """
        case .sunset:
            "Stay after it sets. Clouds can catch color in the afterglow, and blue hour follows."
        case .clear:
            "Expect crisp, hard light and plain skies at golden hour. At night, clear skies suit the stars and the Milky Way."
        case .partlyCloudy:
            "Broken cloud gives skies texture and catches color at sunrise and sunset, while moving shadows make landscapes dramatic."
        case .cloudy:
            """
            Overcast light is soft and even, which suits portraits, forests, waterfalls and close-ups, though it usually \
            mutes sunrise and sunset.
            """
        case .fog:
            """
            Fog simplifies a scene and layers it with depth. Look for light rays through trees, or climb above it to see \
            it fill the valleys.
            """
        case .precipitation:
            """
            Keep your gear covered. Wet streets reflect lights, and a storm's breaks bring dramatic light, with rainbows \
            opposite a low sun.
            """
        case .uvIndex:
            """
            A high index means harsh light from high overhead, so shoot portraits in shade and save landscapes for the \
            golden hours. Pack sunscreen too.
            """
        case .horizonSky:
            """
            Color comes from the low sun lighting cloud from below: mid and high cloud over a clear horizon can glow red \
            and orange, while thick low cloud blocks the light. Long visibility keeps distant detail crisp, and haze \
            softens it.
            """
        case .moonPhase:
            """
            A full moon lights landscapes for night scenes but washes out faint stars. Near new moon, the sky is dark \
            enough for the Milky Way, and a thin crescent in twilight makes a subject of its own.
            """
        case .moonrise:
            """
            A full moon rises around sunset. Catch it in blue hour, when it's no brighter than the land, and use a long \
            lens to set it behind a distant landmark.
            """
        case .moonset:
            """
            A full moon sets around sunrise, low and large over a landscape the dawn lights. On other nights, its setting \
            darkens the sky for the stars.
            """
        case .darkSky:
            """
            The window for the Milky Way, star fields and the night sky. Get away from city lights, and give your eyes 20 \
            minutes to adjust.
            """
        }
    }
}
