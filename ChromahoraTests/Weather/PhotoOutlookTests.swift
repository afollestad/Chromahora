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
        #expect(assessment.reasons == ["Low cloud blocks the sun"])
    }

    /// Below Good, what holds it back leads.
    @Test func whatLowersAPoorRatingLeads() {
        let assessment = assess(.evening, Readings(lowCloud: 0.5, highCloud: 0.8, upperCloud: 0.8, windSpeed: 1))

        #expect(assessment.rating == .poor)
        #expect(assessment.reasons == ["Thick high cloud may mute color", "Low cloud may block the sun", "Calm air for reflections"])
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
        #expect(assess(.evening, readings).reasons == ["Clean air after rain", "No cloud to catch color"])

        readings.chanceBefore = 0.49
        #expect(assess(.evening, readings).rating == .good)
    }

    /// Rain still possible in the session hasn't cleared, and costs a level of its own.
    @Test func rainThatLingersDoesNotClear() {
        let readings = Readings(precipitation: .rain, precipitationChance: 0.3, precipitationBefore: .rain, chanceBefore: 0.9)

        #expect(assess(.evening, readings).rating == .fair)
        #expect(assess(.evening, readings).reasons == ["30% chance of rain", "No cloud to catch color"])
    }

    @Test func windLowersItALevel() {
        var readings = colorful
        readings.windSpeed = PhotoOutlook.windyWind

        #expect(assess(.evening, readings).rating == .great)
        #expect(assess(.evening, readings).reasons == ["High cloud to catch color", "Wind moves hair, trees and water"])
    }

    /// Every step adds up before the scale's ends stop it, so a rise beyond the top still cancels a drop.
    @Test func stepsAddUpBeforeTheScaleStopsThem() {
        var readings = colorful
        readings.precipitationBefore = .rain
        readings.chanceBefore = 0.8
        readings.visibility = 4_000

        #expect(assess(.evening, readings).rating == .excellent)
        #expect(assess(.evening, readings).reasons == ["High cloud to catch color", "Clean air after rain", "Haze dulls color and detail"])
    }

    // MARK: Precipitation, fog and haze

    @Test func possiblePrecipitationLowersItALevel() {
        let readings = Readings(precipitation: .rain, precipitationChance: 0.4)

        #expect(assess(.evening, readings).rating == .fair)
        #expect(assess(.evening, readings).reasons == ["40% chance of rain", "No cloud to catch color"])
        #expect(assess(.evening, Readings(precipitation: .rain, precipitationChance: 0.29)).rating == .good)
    }

    /// Likely precipitation costs a level and holds the rest at Fair, naming its type.
    @Test func likelyPrecipitationHoldsItAtFair() {
        let readings = Readings(precipitation: .snow, precipitationChance: 0.8)

        #expect(assess(.night, readings).rating == .fair)
        #expect(assess(.night, readings).reasons == ["80% chance of snow", "Clear sky for stars"])
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
        #expect(assess(.evening, readings).reasons == ["Fog hides the sky", "High cloud to catch color"])
        #expect(assess(.night, readings).rating == .poor)
        #expect(assess(.night, readings).reasons == ["Fog hides the stars", "Clear sky for stars"])
    }

    @Test(arguments: [(1_000.0, OutlookRating.great), (4_999, .great), (5_000, .excellent)])
    func hazeLowersItALevel(visibility: Double, rating: OutlookRating) {
        var readings = colorful
        readings.visibility = visibility

        #expect(assess(.evening, readings).rating == rating)
    }

    @Test func hazeDimsTheStarsAtNight() {
        let assessment = assess(.night, Readings(visibility: 4_000))

        #expect(assessment.rating == .great)
        #expect(assessment.reasons == ["Clear sky for stars", "Haze dims the stars"])
    }

    // MARK: Daylight

    @Test(arguments: [
        (0.1, 0, OutlookRating.good, ["No cloud to soften the light"]),
        (0.5, 5, .good, ["Broken cloud, uneven light"]),
        (0.75, 0, .great, ["Soft light under cloud"]),
        (0.1, 6, .fair, ["Harsh light, UV 6", "No cloud to soften the light"]),
        (0.1, 8, .poor, ["Harsh light, UV 8", "No cloud to soften the light"]),
        (0.9, 11, .fair, ["Harsh light, UV 11", "Soft light under cloud"])
    ])
    func daylightRatesHowSoftTheLightIs(cloudCover: Double, peakUV: Int, rating: OutlookRating, reasons: [String]) {
        let assessment = assess(.daylight, Readings(cloudCover: cloudCover, peakUV: peakUV))

        #expect(assessment.rating == rating)
        #expect(assessment.reasons == reasons)
    }

    /// Wind tosses hair and clothing in a portrait whatever the light, but calm air only earns a
    /// mention where the low sun lights a reflection.
    @Test func windLowersDaylightButCalmEarnsNoMention() {
        let windy = assess(.daylight, Readings(cloudCover: 0.9, windSpeed: PhotoOutlook.windyWind))

        #expect(windy.rating == .good)
        #expect(windy.reasons == ["Soft light under cloud", "Wind moves hair, trees and water"])
        #expect(assess(.daylight, Readings(cloudCover: 0.9, windSpeed: 0)).reasons == ["Soft light under cloud"])
    }

    // MARK: Night

    @Test(arguments: [
        (0.25, OutlookRating.excellent, "Clear sky for stars"), (0.26, .good, "Cloud hides some stars"),
        (0.5, .good, "Cloud hides some stars"), (0.6, .fair, "Cloud hides most stars"), (0.75, .poor, "Cloud hides the stars")
    ])
    func theNightRatesHowMuchSkyShows(cloudCover: Double, rating: OutlookRating, reason: String) {
        let assessment = assess(.night, Readings(cloudCover: cloudCover))

        #expect(assessment.rating == rating)
        #expect(assessment.reasons == [reason])
    }

    @Test func aMoonUpAllNightHoldsItAtFair() {
        #expect(assess(.night, Readings(), night: .moonUp).rating == .fair)
        #expect(assess(.night, Readings(), night: .moonUp).reasons == ["Moonlight washes out stars", "Clear sky for stars"])
        #expect(assess(.night, Readings(), night: .moonUnknown).rating == .excellent)
    }

    @Test func aWindyNightLowersItButCalmEarnsNoMention() {
        #expect(assess(.night, Readings(windSpeed: 9)).rating == .great)
        #expect(assess(.night, Readings(windSpeed: 9)).reasons == ["Clear sky for stars", "Wind shakes tripods and trees"])
        #expect(assess(.night, Readings(windSpeed: 0)).reasons == ["Clear sky for stars"])
    }

    @Test func aPoorRatingStopsAtTheBottom() {
        #expect(assess(.night, Readings(cloudCover: 0.9, visibility: 2_000, windSpeed: 9)).rating == .poor)
    }
}
