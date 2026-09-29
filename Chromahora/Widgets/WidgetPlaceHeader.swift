//
//  WidgetPlaceHeader.swift
//  Chromahora
//

import SwiftUI

/// The place a widget is for, named as the app's title names it, with the arrow that marks the
/// device's own fix.
struct WidgetPlaceHeader: View {
    let place: Place
    let deviceName: String?

    var body: some View {
        HStack(spacing: 4) {
            Text(place.title(deviceName: deviceName))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let glyph = place.glyph {
                Image(systemName: glyph)
                    .imageScale(.small)
            }
        }
        .font(.headline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(place.spokenTitle(deviceName: deviceName))
    }
}

#Preview {
    WidgetPlaceHeader(place: MockPlaceProvider.sanFrancisco, deviceName: "San Francisco")
}
