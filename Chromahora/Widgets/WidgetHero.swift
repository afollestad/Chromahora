//
//  WidgetHero.swift
//  Chromahora
//

import SwiftUI

/// The value a widget leads with, in large light type, as Apple Weather's leads with the
/// temperature. It shrinks rather than wraps, since the widget's size is fixed, but only when it
/// can't fit: without its layout priority, a stack shrinks it to leave room for its spacers.
struct WidgetHero: View {
    let text: Text

    init(_ text: Text) {
        self.text = text
    }

    init(_ string: String) {
        text = Text(string)
    }

    var body: some View {
        text
            .font(.largeTitle.weight(.light))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .layoutPriority(1)
    }
}

#Preview {
    VStack(alignment: .leading) {
        WidgetHero("6:05 PM")
        WidgetHero(Text("\(Image(systemName: "moonphase.waxing.crescent")) 31%"))
    }
}
