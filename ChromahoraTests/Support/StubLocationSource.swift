//
//  StubLocationSource.swift
//  ChromahoraTests
//

import Foundation
@testable import Chromahora

/// Plays `script`, then keeps the stream open, as a real source does while it waits
/// for a fix, until the listener stops.
@MainActor
final class StubLocationSource: LocationSource {
    var script: [LocationUpdate] = []
    /// Held so each stream stays open after its script.
    private var continuations: [AsyncStream<LocationUpdate>.Continuation] = []

    func updates() -> AsyncStream<LocationUpdate> {
        let (stream, continuation) = AsyncStream<LocationUpdate>.makeStream()
        for update in script {
            continuation.yield(update)
        }
        continuations.append(continuation)
        return stream
    }
}
