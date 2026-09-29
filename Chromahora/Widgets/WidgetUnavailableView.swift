//
//  WidgetUnavailableView.swift
//  Chromahora
//

import SwiftUI

/// What a widget shows when today's sun times couldn't load, from the cache or the network,
/// until its next try.
struct WidgetUnavailableView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "sun.horizon")
                .font(.title2)
                .accessibilityHidden(true)
            Text("Sun times will show once they load.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    WidgetUnavailableView()
        .frame(width: 140, height: 140)
}
