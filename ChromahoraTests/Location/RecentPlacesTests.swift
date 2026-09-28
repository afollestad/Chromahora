//
//  RecentPlacesTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

@MainActor
struct RecentPlacesTests {
    private let defaults = InMemoryDefaults()
    private let kyoto = Place(latitude: 35.0, longitude: 135.8, source: .chosen(name: "Kyoto", timeZone: "Asia/Tokyo"))
    private let reykjavik = Place(latitude: 64.1, longitude: -21.9, source: .chosen(name: "Reykjavík", timeZone: "Atlantic/Reykjavik"))

    private func makeRecents() -> RecentPlaces {
        RecentPlaces(defaults: defaults)
    }

    @Test func theNewestComesFirst() {
        let recents = makeRecents()

        recents.add(kyoto)
        recents.add(reykjavik)

        #expect(recents.places == [reykjavik, kyoto])
    }

    @Test func choosingARecentPlaceMovesItUp() {
        let recents = makeRecents()

        recents.add(kyoto)
        recents.add(reykjavik)
        recents.add(kyoto)

        #expect(recents.places == [kyoto, reykjavik])
    }

    /// Two places in one cell share sun times but not names, and the person picked both.
    @Test func placesInOneCellAreKeptApart() {
        let recents = makeRecents()
        let kyotoStation = Place(latitude: 35.0, longitude: 135.76, source: .chosen(name: "Kyoto Station", timeZone: "Asia/Tokyo"))

        recents.add(kyoto)
        recents.add(kyotoStation)

        #expect(recents.places == [kyotoStation, kyoto])
    }

    @Test func theOldestGoPastCapacity() {
        let recents = makeRecents()
        let places = (0...RecentPlaces.capacity).map {
            Place(latitude: Double($0), longitude: 0, source: .chosen(name: "Place \($0)", timeZone: "UTC"))
        }

        for place in places {
            recents.add(place)
        }

        #expect(recents.places == Array(places.dropFirst().reversed()))
    }

    /// The forecast cache keeps a place per record, and needs one for each recent place and the device's.
    @Test func everyRecentPlaceFitsTheForecastCache() {
        #expect(ForecastCache.capacity > RecentPlaces.capacity)
    }

    /// The device's place always leads the sheet, so it's never recent.
    @Test func onlyChosenPlacesAreKept() {
        let recents = makeRecents()

        recents.add(Place(latitude: 37.8, longitude: -122.4, source: .device))
        recents.add(Place(latitude: 34.1, longitude: -118.2, source: .timeZone("America/Los_Angeles")))

        #expect(recents.places.isEmpty)
    }

    @Test func recentPlacesOutliveARelaunch() {
        makeRecents().add(kyoto)

        #expect(makeRecents().places == [kyoto])
    }

    @Test func clearForgetsThemForGood() {
        let recents = makeRecents()
        recents.add(kyoto)

        recents.clear()

        #expect(recents.places.isEmpty)
        #expect(makeRecents().places.isEmpty)
    }

    @Test func unreadableDataReadsAsNone() {
        defaults.set(Data("{".utf8), forKey: "recentPlaces")

        #expect(makeRecents().places.isEmpty)
    }
}
