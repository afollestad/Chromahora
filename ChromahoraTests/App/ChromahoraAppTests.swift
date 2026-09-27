//
//  ChromahoraAppTests.swift
//  ChromahoraTests
//

import Testing
@testable import Chromahora

struct ChromahoraAppTests {
    /// If this ever fails, the app running under the tests fetches sun times and asks for location mid-run.
    @Test func knowsWhenItsHostingTests() {
        #expect(ChromahoraApp.isHostingTests)
    }
}
