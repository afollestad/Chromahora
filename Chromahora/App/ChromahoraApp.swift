//
//  ChromahoraApp.swift
//  Chromahora
//
//  Created by Aidan Follestad on 9/26/26.
//

import SwiftUI

@main
struct ChromahoraApp: App {
    var body: some Scene {
        WindowGroup {
            // The one place to swap in a real provider once solar data is available.
            ContentView(provider: MockSolarDayProvider())
        }
    }
}
