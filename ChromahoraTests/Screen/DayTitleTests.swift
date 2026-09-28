//
//  DayTitleTests.swift
//  ChromahoraTests
//

import Foundation
import Testing
@testable import Chromahora

struct DayTitleTests {
    /// Monday evening in GMT is already Tuesday in Tokyo. Read in the process's zone instead, one of
    /// the two would name the wrong day wherever the tests run.
    @Test func titlesReadInTheGivenZone() throws {
        let mondayEvening = Date(timeIntervalSince1970: 1_790_000_000 + 6 * 60 * 60)
        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))

        #expect(mondayEvening.dayTitle(in: .gmt) == "Monday, September 21")
        #expect(mondayEvening.dayTitle(in: tokyo) == "Tuesday, September 22")
    }
}
