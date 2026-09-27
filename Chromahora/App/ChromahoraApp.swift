//
//  ChromahoraApp.swift
//  Chromahora
//
//  Created by Aidan Follestad on 9/26/26.
//

import SwiftUI

@main
struct ChromahoraApp: App {
    #if DEBUG
    @State private var debug = DebugSettings.fromLaunchArguments()
    #endif

    var body: some Scene {
        WindowGroup {
            // The one place to swap in a real provider once solar data is available.
            #if DEBUG
            ContentView(
                provider: DebugSolarDayProvider(base: MockSolarDayProvider(), settings: debug),
                selectedDate: debug.nowOverride ?? .now
            )
            .environment(debug)
            #else
            ContentView(provider: MockSolarDayProvider())
            #endif
        }
    }
}
