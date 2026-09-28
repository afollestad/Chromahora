//
//  PlaceNamesTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

/// Held lookups are awaited, so a regression that never makes one would hang without the time limit.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PlaceNamesTests {
    private let search = StubPlaceSearch()
    private let defaults = InMemoryDefaults()
    private let sanFrancisco = Place(latitude: 37.8, longitude: -122.4, source: .device)

    private func makeNames() -> PlaceNames {
        PlaceNames(search: search, defaults: defaults)
    }

    @Test func aPlaceIsLookedUpOnce() async {
        let names = makeNames()
        #expect(names.name(for: sanFrancisco) == nil)

        await names.load(sanFrancisco)
        await names.load(Place(latitude: 37.79, longitude: -122.41, source: .device))

        #expect(names.name(for: sanFrancisco) == "San Francisco")
        #expect(search.townNameRequests == [sanFrancisco])
    }

    /// A chosen place has its own name, and the time zone names its city.
    @Test func onlyDevicePlacesAreLookedUp() async {
        let names = makeNames()
        let kyoto = Place(latitude: 35.0, longitude: 135.8, source: .chosen(name: "Kyoto", timeZone: "Asia/Tokyo"))
        let losAngeles = Place(latitude: 34.1, longitude: -118.2, source: .timeZone("America/Los_Angeles"))

        await names.load(kyoto)
        await names.load(losAngeles)

        #expect(search.townNameRequests.isEmpty)
        #expect(names.name(for: kyoto) == nil)
        #expect(names.name(for: losAngeles) == nil)
    }

    /// Offline, the lookup fails, and the next finished location lookup asks again.
    @Test func aFailureLeavesThePlaceUnnamedUntilAskedAgain() async {
        let names = makeNames()
        search.error = StubError()

        await names.load(sanFrancisco)
        #expect(names.name(for: sanFrancisco) == nil)

        search.error = nil
        await names.load(sanFrancisco)
        #expect(names.name(for: sanFrancisco) == "San Francisco")
        #expect(search.townNameRequests.count == 2)
    }

    /// A relaunch names the last place at once, even offline.
    @Test func theLastNameOutlivesARelaunch() async {
        await makeNames().load(sanFrancisco)
        search.error = StubError()

        #expect(makeNames().name(for: sanFrancisco) == "San Francisco")
        #expect(search.townNameRequests.count == 1)
    }

    /// A lookup for a place the device has left can finish after the newest one's, and mustn't
    /// replace the name the next launch shows at once.
    @Test func onlyTheNewestPlacesNameOutlivesARelaunch() async throws {
        let names = makeNames()
        let oakland = Place(latitude: 37.8, longitude: -122.2, source: .device)
        search.holdsResponses = true
        var requests = search.heldRequests.makeAsyncIterator()

        let left = Task { await names.load(sanFrancisco) }
        let leftRequest = try #require(await requests.next())
        let newest = Task { await names.load(oakland) }
        let newestRequest = try #require(await requests.next())
        newestRequest.answer("Oakland")
        await newest.value
        leftRequest.answer("San Francisco")
        await left.value

        search.error = StubError()
        #expect(makeNames().name(for: oakland) == "Oakland")
    }

    /// Each finished location lookup restarts the view's naming task, cancelling the one before.
    /// The new one joins the lookup that's out, which the cancellation mustn't throw away.
    @Test func aCancelledCallerLeavesTheLookupToTheNext() async throws {
        let names = makeNames()
        search.holdsResponses = true
        var requests = search.heldRequests.makeAsyncIterator()

        let first = Task { await names.load(sanFrancisco) }
        let request = try #require(await requests.next())
        first.cancel()
        let second = Task { await names.load(sanFrancisco) }
        // Lets the cancellation land, and the second caller arrive, while the lookup is still out.
        await Task.yield()
        request.answer("San Francisco")
        await first.value
        await second.value

        #expect(names.name(for: sanFrancisco) == "San Francisco")
        #expect(search.townNameRequests == [sanFrancisco])
    }
}
