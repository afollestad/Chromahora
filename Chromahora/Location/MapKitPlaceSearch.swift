//
//  MapKitPlaceSearch.swift
//  Chromahora
//

import MapKit

/// Apple Maps' search, the only code that reaches MapKit. It keeps nothing between calls, so
/// every window can share one: each search runs a completer of its own, which a newer search
/// in another window can't cancel or hold up.
///
/// Nothing here sets a search region, so the app sends no coordinates with a query. The town
/// lookup sends only a place's rounded coordinates.
struct MapKitPlaceSearch: PlaceSearch {
    /// Towns, landmarks and features such as parks and peaks: the places a photographer heads for.
    private static let completerTypes: MKLocalSearchCompleter.ResultType = [.address, .pointOfInterest, .physicalFeature]
    /// Towns and regions, but not street addresses or postal codes, which would name a place by a
    /// house, nor whole countries, whose middle says little about any spot's sun.
    private static let addressFilter = MKAddressFilter(including: [.locality, .subLocality, .subAdministrativeArea, .administrativeArea])
    /// Places a photographer shoots, leaving out the shops and restaurants that share their names
    /// and crowd them out.
    private static let pointOfInterestFilter = MKPointOfInterestFilter(including: [
        .beach, .campground, .castle, .fortress, .hiking, .landmark, .marina, .nationalMonument,
        .nationalPark, .park, .picnicArea, .scenicView, .skiing, .surfing, .visitorCenter
    ])

    func suggestions(for query: String) async throws -> [PlaceSuggestion] {
        // An empty fragment never calls back, so it would wait forever.
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let completer = MKLocalSearchCompleter()
        completer.resultTypes = Self.completerTypes
        completer.addressFilter = Self.addressFilter
        completer.pointOfInterestFilter = Self.pointOfInterestFilter
        let waiter = CompleterWaiter()
        completer.delegate = waiter
        let completions: [MKLocalSearchCompletion]
        do {
            completions = try await withTaskCancellationHandler {
                try await waiter.answer.wait { completer.queryFragment = query }
            } onCancel: {
                Task { @MainActor in
                    completer.cancel()
                    waiter.answer.cancel()
                }
            }
        } catch let error as MKError where error.code == .placemarkNotFound {
            return []
        }
        var seen = Set<String>()
        return completions
            .map { PlaceSuggestion(title: $0.title, subtitle: $0.subtitle, handle: $0) }
            .filter { seen.insert($0.id).inserted }
    }

    func place(for suggestion: PlaceSuggestion) async throws -> Place {
        guard let completion = suggestion.handle as? MKLocalSearchCompletion else {
            throw PlaceSearchError.notFound
        }
        // Unfiltered, since the completion already names one place. Under the completer's point of
        // interest filter, the search for a town finds nothing, or answers with a park instead.
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        let response: MKLocalSearch.Response
        do {
            response = try await withTaskCancellationHandler {
                try await search.start()
            } onCancel: {
                Task { @MainActor in
                    search.cancel()
                }
            }
        } catch let error as MKError where error.code == .placemarkNotFound {
            throw PlaceSearchError.notFound
        }
        guard let item = response.mapItems.first else {
            throw PlaceSearchError.notFound
        }
        guard let timeZone = item.timeZone else {
            throw PlaceSearchError.noTimeZone
        }
        let coordinate = item.location.coordinate
        return Place(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            source: .chosen(name: suggestion.title, timeZone: timeZone.identifier)
        )
    }

    func townName(of place: Place) async throws -> String? {
        guard let request = MKReverseGeocodingRequest(location: CLLocation(latitude: place.latitude, longitude: place.longitude)) else {
            return nil
        }
        // The completion handler rather than the async `mapItems`, which never returns once cancelled.
        let answer = OneShot<[MKMapItem]>()
        let items = try await withTaskCancellationHandler {
            try await answer.wait {
                request.getMapItems { items, error in
                    answer.finish(items.map { .success($0) } ?? .failure(error ?? MKError(.unknown)))
                }
            }
        } onCancel: {
            Task { @MainActor in
                request.cancel()
                answer.cancel()
            }
        }
        return items.first?.addressRepresentations?.cityName
    }
}

/// Hands a completer's answer to its query to a wait. The completer calls its delegate on the
/// main thread, once per query.
private final class CompleterWaiter: NSObject, MKLocalSearchCompleterDelegate {
    let answer = OneShot<[MKLocalSearchCompletion]>()

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated {
            answer.finish(.success(completer.results))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        MainActor.assumeIsolated {
            answer.finish(.failure(error))
        }
    }
}

/// Waits for one answer to a request sent inside the wait, and ends the wait itself when
/// cancelled, since some of MapKit's requests never answer once cancelled.
private final class OneShot<Value> {
    private var continuation: CheckedContinuation<Value, any Error>?
    private var isCancelled = false

    /// Runs `start`, which sends the request, then waits for its answer. Cancelled beforehand, it
    /// throws without sending.
    func wait(starting start: () -> Void) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            guard !isCancelled else {
                continuation.resume(throwing: CancellationError())
                return
            }
            self.continuation = continuation
            start()
        }
    }

    func cancel() {
        isCancelled = true
        finish(.failure(CancellationError()))
    }

    /// Answers the wait once. An answer after a cancel, or any after the first, finds it answered.
    func finish(_ result: Result<Value, any Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
