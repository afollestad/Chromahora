//
//  PhotoOutlookTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// How readings turn into a rating and its reasons, apart from the hours and the day.
struct PhotoOutlookTests {
    private typealias Readings = PhotoOutlook.Readings

    private func assess(
        _ kind: OutlookSession.Kind, _ readings: Readings, night: PhotoOutlook.NightSky = .dark
    ) -> (rating: OutlookRating, reasons: [String]) {
        PhotoOutlook.assess(kind, readings, night: night)
    }

    /// Mid or high cloud the low sun can light, over little low cloud.
    private var colorful: Readings {
        Readings(lowCloud: 0.1, highCloud: 0.5, upperCloud: 0.5)
    }

    // MARK: Ratings

    @Test func ratingsMoveWithinTheScale() {
        #expect(OutlookRating.fair.moved(by: 1) == .good)
        #expect(OutlookRating.good.moved(by: 5) == .excellent)
        #expect(OutlookRating.good.moved(by: -9) == .poor)
        #expect(OutlookRating.poor < .fair)
    }

    // MARK: Golden and blue hours

    /// Two and six eighths of low cloud, and 30% to 70% of the cloud above it, part the table.
    @Test(arguments: [
        (0.0, 0.0, OutlookRating.good), (0.25, 0.29, .good), (0.25, 0.3, .excellent), (0.1, 0.7, .excellent),
        (0.1, 0.71, .fair), (0.26, 0.1, .fair), (0.5, 0.5, .good), (0.5, 0.8, .poor), (0.74, 0.5, .good),
        (0.75, 0.5, .poor), (0.9, 0.0, .poor)
    ])
    func goldenAndBlueHoursRateTheCloudTheLowSunCanLight(lowCloud: Double, upperCloud: Double, rating: OutlookRating) {
        let readings = Readings(lowCloud: lowCloud, highCloud: upperCloud, upperCloud: upperCloud)

        #expect(assess(.evening, readings).rating == rating)
        #expect(assess(.morning, readings).rating == rating)
    }

    @Test func theCloudIsNamedForItsThickerLayer() {
        #expect(assess(.evening, colorful).reasons == ["High cloud to catch color"])
        #expect(assess(.evening, Readings(lowCloud: 0.1, midCloud: 0.5, highCloud: 0.2, upperCloud: 0.5)).reasons == ["Mid cloud to catch color"])
        #expect(assess(.evening, Readings(midCloud: 0.9, upperCloud: 0.9)).reasons == ["Thick mid cloud may mute color"])
    }

    @Test func aLowDeckBlocksTheSunWhateverIsAboveIt() {
        let assessment = assess(.morning, Readings(lowCloud: 0.8, highCloud: 0.5, upperCloud: 0.5))

        #expect(assessment.rating == .poor)
        #expect(assessment.reasons == ["Low cloud may block the sun"])
    }

    /// Below Good, what holds it back leads.
    @Test func whatLowersAPoorRatingLeads() {
        let assessment = assess(.evening, Readings(lowCloud: 0.5, highCloud: 0.8, upperCloud: 0.8, windSpeed: 1))

        #expect(assessment.rating == .poor)
        #expect(assessment.reasons == ["Thick high cloud may mute color", "Some low cloud", "Calm air for reflections"])
    }

    /// Calm air makes reflections but no better light, so it only earns a mention.
    @Test func calmAirIsMentionedWithoutARise() {
        var readings = colorful
        readings.windSpeed = PhotoOutlook.calmWind

        #expect(assess(.evening, readings).rating == .excellent)
        #expect(assess(.evening, readings).reasons == ["High cloud to catch color", "Calm air for reflections"])

        readings.windSpeed = 1.6
        #expect(assess(.evening, readings).reasons == ["High cloud to catch color"])
    }

    @Test func rainThatClearsBeforeTheLowSunRaisesIt() {
        var readings = Readings(precipitationBefore: .rain, chanceBefore: 0.5)

        #expect(assess(.evening, readings).rating == .great)
        #expect(assess(.evening, readings).reasons == ["Clearing after rain", "Clear sky"])

        readings.chanceBefore = 0.49
        #expect(assess(.evening, readings).rating == .good)
    }

    /// Rain still possible in the session hasn't cleared, and costs a level of its own.
    @Test func rainThatLingersDoesNotClear() {
        let readings = Readings(precipitation: .rain, precipitationChance: 0.3, precipitationBefore: .rain, chanceBefore: 0.9)

        #expect(assess(.evening, readings).rating == .fair)
        #expect(assess(.evening, readings).reasons == ["30% chance of rain", "Clear sky"])
    }

    @Test func windShakesTheTripod() {
        var readings = colorful
        readings.windSpeed = PhotoOutlook.windyWind

        #expect(assess(.evening, readings).rating == .great)
        #expect(assess(.evening, readings).reasons == ["High cloud to catch color", "Windy"])
    }

    /// Every step adds up before the scale's ends stop it, so a rise beyond the top still cancels a drop.
    @Test func stepsAddUpBeforeTheScaleStopsThem() {
        var readings = colorful
        readings.precipitationBefore = .rain
        readings.chanceBefore = 0.8
        readings.visibility = 4_000

        #expect(assess(.evening, readings).rating == .excellent)
        #expect(assess(.evening, readings).reasons == ["High cloud to catch color", "Clearing after rain", "Haze"])
    }

    // MARK: Precipitation, fog and haze

    @Test func possiblePrecipitationLowersItALevel() {
        let readings = Readings(precipitation: .rain, precipitationChance: 0.4)

        #expect(assess(.evening, readings).rating == .fair)
        #expect(assess(.evening, readings).reasons == ["40% chance of rain", "Clear sky"])
        #expect(assess(.evening, Readings(precipitation: .rain, precipitationChance: 0.29)).rating == .good)
    }

    /// Likely precipitation costs a level and holds the rest at Fair, naming its type.
    @Test func likelyPrecipitationHoldsItAtFair() {
        let readings = Readings(precipitation: .snow, precipitationChance: 0.8)

        #expect(assess(.night, readings).rating == .fair)
        #expect(assess(.night, readings).reasons == ["80% chance of snow", "Clear sky"])
        #expect(assess(.daylight, Readings(cloudCover: 0.9, precipitation: .rain, precipitationChance: 0.5)).rating == .fair)
    }

    /// A chance with no type is no condition the timeline shows, so it isn't read.
    @Test func aChanceWithoutATypeIsIgnored() {
        #expect(assess(.evening, Readings(precipitationChance: 0.9)).rating == .good)
    }

    @Test func fogHoldsTheSkyAtFairAndTheStarsAtPoor() {
        var readings = colorful
        readings.visibility = 999

        #expect(assess(.evening, readings).rating == .fair)
        #expect(assess(.evening, readings).reasons == ["Fog", "High cloud to catch color"])
        #expect(assess(.night, readings).rating == .poor)
    }

    @Test(arguments: [(1_000.0, OutlookRating.great), (4_999, .great), (5_000, .excellent)])
    func hazeLowersItALevel(visibility: Double, rating: OutlookRating) {
        var readings = colorful
        readings.visibility = visibility

        #expect(assess(.evening, readings).rating == rating)
    }

    // MARK: Daylight

    @Test(arguments: [
        (0.1, 0, OutlookRating.good, ["Clear sky"]),
        (0.5, 5, .good, ["Broken cloud"]),
        (0.75, 0, .great, ["Soft light under cloud"]),
        (0.1, 6, .fair, ["Harsh light, UV 6", "Clear sky"]),
        (0.1, 8, .poor, ["Harsh light, UV 8", "Clear sky"]),
        (0.9, 11, .fair, ["Harsh light, UV 11", "Soft light under cloud"])
    ])
    func daylightRatesHowSoftTheLightIs(cloudCover: Double, peakUV: Int, rating: OutlookRating, reasons: [String]) {
        let assessment = assess(.daylight, Readings(cloudCover: cloudCover, peakUV: peakUV))

        #expect(assessment.rating == rating)
        #expect(assessment.reasons == reasons)
    }

    /// Daylight is about the light, not long exposures or reflections.
    @Test func daylightIgnoresTheWind() {
        #expect(assess(.daylight, Readings(cloudCover: 0.9, windSpeed: 12)).reasons == ["Soft light under cloud"])
        #expect(assess(.daylight, Readings(cloudCover: 0.9, windSpeed: 0)).reasons == ["Soft light under cloud"])
    }

    // MARK: Night

    @Test(arguments: [(0.25, OutlookRating.excellent), (0.26, .good), (0.5, .good), (0.6, .fair), (0.75, .poor)])
    func theNightRatesHowMuchSkyShows(cloudCover: Double, rating: OutlookRating) {
        #expect(assess(.night, Readings(cloudCover: cloudCover)).rating == rating)
    }

    @Test func aMoonUpAllNightHoldsItAtFair() {
        #expect(assess(.night, Readings(), night: .moonUp).rating == .fair)
        #expect(assess(.night, Readings(), night: .moonUp).reasons == ["Moon up", "Clear sky"])
        #expect(assess(.night, Readings(), night: .moonUnknown).rating == .excellent)
    }

    @Test func aWindyNightLowersItButCalmEarnsNoMention() {
        #expect(assess(.night, Readings(windSpeed: 9)).rating == .great)
        #expect(assess(.night, Readings(windSpeed: 0)).reasons == ["Clear sky"])
    }

    @Test func aPoorRatingStopsAtTheBottom() {
        #expect(assess(.night, Readings(cloudCover: 0.9, visibility: 2_000, windSpeed: 9)).rating == .poor)
    }
}
