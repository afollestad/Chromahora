//
//  PlaceSuggestionTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Where a query's physical features land among its places, on lists Apple Maps gave for the
/// queries here.
struct PlaceSuggestionTests {
    @Test func aNearMissStaysAfterThePlaces() {
        let places = [suggestion("Duluth, MN", "United States"), suggestion("Duluth, GA", "United States")]
        let features = [suggestion("Barton Lake", "Isanti County, MN, United States")]

        #expect(PlaceSuggestion.merging(features, into: places, for: "Duluth") == places + features)
    }

    /// Only the first feature moves up, whatever the case and accents of what was typed.
    @Test func theFirstFeatureHoldingTheQueryTakesTheSecondRow() {
        let whitney = [suggestion("Whitney, TX", "United States"), suggestion("Whitney Park", "Saint Cloud, MN, United States")]
        let peaks = [suggestion("Mount Whitney", "Inyo County, CA, United States"), suggestion("Whitney Lake", "Meeker County, MN, United States")]
        let uluru = [suggestion("Uluru Lookout", "Yulara NT 0872, Australia"), suggestion("Ulurukhuti, Chandrapur", "Rayagada, Odisha, India")]
        let rock = [suggestion("Uluṟu / Ayers Rock", "Uluṟu-Kata Tjuṯa, Australia")]

        #expect(PlaceSuggestion.merging(peaks, into: whitney, for: "whitney") == [whitney[0], peaks[0], whitney[1], peaks[1]])
        #expect(PlaceSuggestion.merging(rock, into: uluru, for: "Uluru") == [uluru[0], rock[0], uluru[1]])
    }

    @Test func aFeatureNamedAsTypedLeads() {
        let places = [suggestion("South Lake Tahoe, CA", "United States"), suggestion("Lake Tahoe Nevada State Park", "Washoe Valley, NV")]
        let features = [suggestion("Lake Tahoe", "Western United States, United States"), suggestion("Lake Tahoe", "Iron County, WI, United States")]

        #expect(PlaceSuggestion.merging(features, into: places, for: " lake tahoe ") == [features[0], places[0], places[1], features[1]])
    }

    /// A town named as typed is what Search should choose, with its state after a comma or without.
    @Test func aPlaceNamedAsTypedKeepsTheFirstRow() {
        let town = [suggestion("Lookout Mountain, TN", "United States")]
        let peak = [suggestion("Lookout Mountain", "St. Louis County, MN, United States")]
        let village = [suggestion("Zugspitze", "Brand-Erbisdorf, Saxony, Germany")]
        let summit = [suggestion("Zugspitze", "")]

        #expect(PlaceSuggestion.merging(peak, into: town, for: "Lookout Mountain") == town + peak)
        #expect(PlaceSuggestion.merging(summit, into: village, for: "Zugspitze") == village + summit)
    }

    @Test func featuresAloneKeepTheirOrder() {
        let features = [
            suggestion("Matterhorn", "Europe"),
            suggestion("Matterhorn", "Elko County, NV, United States"),
            suggestion("Matterhorn Peak", "Tuolumne County, CA, United States")
        ]

        #expect(PlaceSuggestion.merging(features, into: [], for: "Matterhorn") == features)
    }

    /// Two rows that read the same can't be told apart, so only the place's is kept.
    @Test func aSuggestionInBothListsIsKeptOnce() {
        let region = NSObject()
        let places = [PlaceSuggestion(title: "Kilimanjaro", subtitle: "Tanzania", handle: region)]
        let features = [suggestion("Kilimanjaro", "Tanzania"), suggestion("Kilimanjaro Dam", "Narok West, Narok, Kenya")]

        let merged = PlaceSuggestion.merging(features, into: places, for: "Kilimanjaro")

        #expect(merged == [places[0], features[1]])
        #expect(merged.first?.handle === region)
    }

    private func suggestion(_ title: String, _ subtitle: String) -> PlaceSuggestion {
        PlaceSuggestion(title: title, subtitle: subtitle)
    }
}
