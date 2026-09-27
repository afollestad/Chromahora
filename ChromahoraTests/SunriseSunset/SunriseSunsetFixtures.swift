//
//  SunriseSunsetFixtures.swift
//  ChromahoraTests
//

import Foundation

/// Responses from sunrise-sunset.org's v2 API, fetched in September 2026 with `time_format=unix`
/// and a one-day range, trimmed to the fields the app reads.
enum SunriseSunsetFixtures {
    struct Fixture {
        /// The zone the request windowed its day to.
        let timeZone: String
        let json: String
    }

    /// San Francisco on September 26, a typical day.
    static let sanFrancisco = Fixture(
        timeZone: "America/Los_Angeles",
        json: """
            {
                "tzid": "America/Los_Angeles",
                "lat": 37.8,
                "lng": -122.4,
                "days": [
                    {
                        "date": "2026-09-26",
                        "sunrise": 1790431261,
                        "sunset": 1790474402,
                        "golden_hour": {
                            "morning": {"begin": 1790430299, "end": 1790433343},
                            "evening": {"begin": 1790472323, "end": 1790475363}
                        },
                        "blue_hour": {
                            "morning": {"begin": 1790429690, "end": 1790430299},
                            "evening": {"begin": 1790475363, "end": 1790475970}
                        },
                        "solar_position": {"solar_noon_altitude": 50.71}
                    }
                ]
            }
            """
    )

    /// San Francisco on September 26 windowed to Tokyo's day, so the evening's crossings come before the morning's.
    static let sanFranciscoInTokyo = Fixture(
        timeZone: "Asia/Tokyo",
        json: """
            {
                "tzid": "Asia/Tokyo",
                "lat": 37.8,
                "lng": -122.4,
                "days": [
                    {
                        "date": "2026-09-26",
                        "sunrise": 1790431261,
                        "sunset": 1790388095,
                        "golden_hour": {
                            "morning": {"begin": 1790430299, "end": 1790433343},
                            "evening": {"begin": 1790386017, "end": 1790389056}
                        },
                        "blue_hour": {
                            "morning": {"begin": 1790429690, "end": 1790430299},
                            "evening": {"begin": 1790389056, "end": 1790389664}
                        },
                        "solar_position": {"solar_noon_altitude": 51.1}
                    }
                ]
            }
            """
    )

    /// Reykjavík on December 21: golden hour from 10:30 to 16:21, with no daylight.
    static let reykjavik = Fixture(
        timeZone: "Atlantic/Reykjavik",
        json: """
            {
                "tzid": "Atlantic/Reykjavik",
                "lat": 64.1,
                "lng": -21.9,
                "days": [
                    {
                        "date": "2026-12-21",
                        "sunrise": 1797852082,
                        "sunset": 1797867002,
                        "golden_hour": {
                            "morning": {"begin": 1797848966, "end": null},
                            "evening": {"begin": null, "end": 1797870118}
                        },
                        "blue_hour": {
                            "morning": {"begin": 1797847345, "end": 1797848966},
                            "evening": {"begin": 1797870118, "end": 1797871740}
                        },
                        "solar_position": {"solar_noon_altitude": 2.46}
                    }
                ]
            }
            """
    )

    /// Trondheim on June 21: golden hour across midnight, with no night or blue hour.
    static let trondheim = Fixture(
        timeZone: "Europe/Oslo",
        json: """
            {
                "tzid": "Europe/Oslo",
                "lat": 63.4,
                "lng": 10.4,
                "days": [
                    {
                        "date": "2026-06-21",
                        "sunrise": 1782003774,
                        "sunset": 1782077851,
                        "golden_hour": {
                            "morning": {"begin": null, "end": 1782010165},
                            "evening": {"begin": 1782071461, "end": null}
                        },
                        "blue_hour": {
                            "morning": {"begin": null, "end": null},
                            "evening": {"begin": null, "end": null}
                        },
                        "solar_position": {"solar_noon_altitude": 50.04}
                    }
                ]
            }
            """
    )

    /// St. Petersburg on June 21: blue hour runs past midnight at both ends.
    static let stPetersburg = Fixture(
        timeZone: "Europe/Moscow",
        json: """
            {
                "tzid": "Europe/Moscow",
                "lat": 59.9,
                "lng": 30.3,
                "days": [
                    {
                        "date": "2026-06-21",
                        "sunrise": 1782002141,
                        "sunset": 1782069932,
                        "golden_hour": {
                            "morning": {"begin": 1781999050, "end": 1782006901},
                            "evening": {"begin": 1782065172, "end": 1782073022}
                        },
                        "blue_hour": {
                            "morning": {"begin": 1781995910, "end": 1781999050},
                            "evening": {"begin": 1782073022, "end": 1781989749}
                        },
                        "solar_position": {"solar_noon_altitude": 53.54}
                    }
                ]
            }
            """
    )

    /// Tromsø on December 10: blue, golden and blue again, with no sunrise.
    static let tromso = Fixture(
        timeZone: "Europe/Oslo",
        json: """
            {
                "tzid": "Europe/Oslo",
                "lat": 69.7,
                "lng": 19,
                "days": [
                    {
                        "date": "2026-12-10",
                        "sunrise": null,
                        "sunset": null,
                        "golden_hour": {
                            "morning": {"begin": 1796893643, "end": null},
                            "evening": {"begin": null, "end": 1796904347}
                        },
                        "blue_hour": {
                            "morning": {"begin": 1796890527, "end": 1796893643},
                            "evening": {"begin": 1796904347, "end": 1796907463}
                        },
                        "solar_position": {"solar_noon_altitude": -2.63}
                    }
                ]
            }
            """
    )

    /// Longyearbyen on June 21: midnight sun, with every crossing null.
    static let longyearbyenJune = Fixture(
        timeZone: "Arctic/Longyearbyen",
        json: """
            {
                "tzid": "Arctic/Longyearbyen",
                "lat": 78.2,
                "lng": 15.6,
                "days": [
                    {
                        "date": "2026-06-21",
                        "sunrise": null,
                        "sunset": null,
                        "golden_hour": {
                            "morning": {"begin": null, "end": null},
                            "evening": {"begin": null, "end": null}
                        },
                        "blue_hour": {
                            "morning": {"begin": null, "end": null},
                            "evening": {"begin": null, "end": null}
                        },
                        "solar_position": {"solar_noon_altitude": 35.24}
                    }
                ]
            }
            """
    )

    /// Longyearbyen on December 21: polar night, with every crossing null.
    static let longyearbyenDecember = Fixture(
        timeZone: "Arctic/Longyearbyen",
        json: """
            {
                "tzid": "Arctic/Longyearbyen",
                "lat": 78.2,
                "lng": 15.6,
                "days": [
                    {
                        "date": "2026-12-21",
                        "sunrise": null,
                        "sunset": null,
                        "golden_hour": {
                            "morning": {"begin": null, "end": null},
                            "evening": {"begin": null, "end": null}
                        },
                        "blue_hour": {
                            "morning": {"begin": null, "end": null},
                            "evening": {"begin": null, "end": null}
                        },
                        "solar_position": {"solar_noon_altitude": -11.64}
                    }
                ]
            }
            """
    )

    /// Chicago on March 8, 2026, a 23-hour day.
    static let chicagoSpringForward = Fixture(
        timeZone: "America/Chicago",
        json: """
            {
                "tzid": "America/Chicago",
                "lat": 41.9,
                "lng": -87.6,
                "days": [
                    {
                        "date": "2026-03-08",
                        "sunrise": 1772972029,
                        "sunset": 1773013742,
                        "golden_hour": {
                            "morning": {"begin": 1772971006, "end": 1772974257},
                            "evening": {"begin": 1773011511, "end": 1773014767}
                        },
                        "blue_hour": {
                            "morning": {"begin": 1772970361, "end": 1772971006},
                            "evening": {"begin": 1773014767, "end": 1773015412}
                        },
                        "solar_position": {"solar_noon_altitude": 43.43}
                    }
                ]
            }
            """
    )

    /// Chicago on November 1, 2026, a 25-hour day.
    static let chicagoFallBack = Fixture(
        timeZone: "America/Chicago",
        json: """
            {
                "tzid": "America/Chicago",
                "lat": 41.9,
                "lng": -87.6,
                "days": [
                    {
                        "date": "2026-11-01",
                        "sunrise": 1793535778,
                        "sunset": 1793573061,
                        "golden_hour": {
                            "morning": {"begin": 1793534706, "end": 1793538162},
                            "evening": {"begin": 1793570678, "end": 1793574132}
                        },
                        "blue_hour": {
                            "morning": {"begin": 1793534038, "end": 1793534706},
                            "evening": {"begin": 1793574132, "end": 1793574800}
                        },
                        "solar_position": {"solar_noon_altitude": 33.5}
                    }
                ]
            }
            """
    )
}
