//
//  LoadState+Testing.swift
//  ChromahoraTests
//

import Foundation
@testable import Chromahora

/// Reads a load state's case, which store tests check at every step.
extension SolarDayStore.LoadState {
    var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    var loadedDay: SolarDay? {
        if case .loaded(let day) = self { day } else { nil }
    }

    var failure: (any Error)? {
        if case .failed(let error) = self { error } else { nil }
    }
}
