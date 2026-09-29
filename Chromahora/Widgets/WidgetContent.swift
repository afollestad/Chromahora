//
//  WidgetContent.swift
//  Chromahora
//

import SwiftUI

/// A widget's content for `entry`, filling it from the top leading corner, or the note that its
/// sun times haven't loaded yet. Text stops growing at `DynamicTypeSize.xLarge`, the largest a
/// widget's fixed size holds without cutting words short.
struct WidgetContent<Loaded: View>: View {
    let entry: SkyEntry
    @ViewBuilder let loaded: (SkyContent) -> Loaded

    var body: some View {
        Group {
            switch entry.state {
            case .loaded(let content):
                loaded(content)
            case .unavailable:
                WidgetUnavailableView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

#Preview {
    WidgetContent(entry: SkyEntry(date: .now, state: .unavailable)) { _ in
        EmptyView()
    }
    .frame(width: 164, height: 164)
}
