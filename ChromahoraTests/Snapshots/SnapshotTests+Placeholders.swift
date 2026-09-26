//
//  SnapshotTests+Placeholders.swift
//  ChromahoraTests
//

import Testing
@testable import Chromahora

extension SnapshotTests {
    @Test func failedToLoad() async throws {
        let provider = StubSolarDayProvider()
        provider.error = StubError()
        try await assertScreenSnapshot(of: ContentView(provider: provider, selectedDate: time(12)))
    }
}
