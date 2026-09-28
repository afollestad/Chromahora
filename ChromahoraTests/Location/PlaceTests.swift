//
//  PlaceTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// How each kind of place is named in the title and noted in the location sheet. Notes read
/// in `en_US`, which the test scripts pin.
struct PlaceTests {
    private let device = Place(latitude: 37.8, longitude: -122.4, source: .device)
    private let losAngeles = Place(latitude: 34.1, longitude: -118.2, source: .timeZone("America/Los_Angeles"))
    private let kyoto = Place(latitude: 35.0, longitude: 135.8, source: .chosen(name: "Kyoto", timeZone: "Asia/Tokyo"))

    @Test func titlesNameEachKindOfPlace() {
        #expect(device.title(deviceName: "San Francisco") == "San Francisco")
        #expect(device.title(deviceName: nil) == "Current Location")
        #expect(losAngeles.title(deviceName: "San Francisco") == "Los Angeles")
        #expect(kyoto.title(deviceName: "San Francisco") == "Kyoto")
    }

    @Test func onlyTheDevicesOwnPlacesHaveGlyphs() {
        #expect(device.glyph == "location.fill")
        #expect(losAngeles.glyph == "location")
        #expect(kyoto.glyph == nil)
    }

    /// A chosen place names the zone its times read in, by the zone's everyday name, which
    /// covers daylight saving time as well as standard time.
    @Test func notesSayWhereTheTimesComeFrom() {
        #expect(device.note == nil)
        #expect(losAngeles.note == "Approximate, from your time zone (Los Angeles)")
        #expect(kyoto.note == "Times in Japan Standard Time")
        #expect(Place(latitude: 39.7, longitude: -105, source: .chosen(name: "Denver", timeZone: "America/Denver")).note == "Times in Mountain Time")
    }

    @Test func onlyAChosenPlaceHasANameAndZone() {
        #expect(device.name == nil)
        #expect(device.timeZone == nil)
        #expect(losAngeles.timeZone == nil)
        #expect(kyoto.name == "Kyoto")
        #expect(kyoto.timeZone == TimeZone(identifier: "Asia/Tokyo"))
    }

    /// The stored device fix was written before chosen places existed, in the shape synthesized
    /// coding gave the two cases then.
    @Test func placesStoredBeforeChosenOnesStillRead() throws {
        let stored = #"[{"latitudeTenths":378,"longitudeTenths":-1224,"source":{"device":{}}},"#
            + #"{"latitudeTenths":341,"longitudeTenths":-1182,"source":{"timeZone":{"_0":"America\/Los_Angeles"}}}]"#
        let places = try JSONDecoder().decode([Place].self, from: Data(stored.utf8))
        #expect(places == [device, losAngeles])
    }

    /// Recent places are stored as JSON, beside device places stored before chosen ones existed.
    @Test func placesRoundTripThroughJSON() throws {
        let places = [device, losAngeles, kyoto]
        let decoded = try JSONDecoder().decode([Place].self, from: JSONEncoder().encode(places))
        #expect(decoded == places)
    }
}
