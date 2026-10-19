//
//  ComplicationDisc.swift
//  Chromahora
//

import SwiftUI
import WidgetKit

/// The disc behind a circular complication, with lines sized from its width and inset from its
/// curve. The phase and outlook complications share it, so side by side on a face their readings
/// match. A long line, like a two-digit hour, shrinks rather than truncate.
struct ComplicationDisc<Content: View>: View {
    @ViewBuilder let content: (DiscScale) -> Content

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            GeometryReader { proxy in
                let scale = DiscScale(width: min(proxy.size.width, proxy.size.height))
                content(scale)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(scale.width * 0.12)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

/// A circular complication's font sizes, as shares of its disc's width. The disc measures 46 pt
/// on a 49 mm Ultra's face and 51 pt in Modular on a 46 mm watch, so fixed sizes that fill one
/// crowd the other's curve.
struct DiscScale {
    let width: CGFloat

    /// A reading, as large as a face's own, like Heart Rate's "82".
    var reading: CGFloat {
        width * 0.37
    }

    /// The name over a reading and the line under it, under half its size as a face's own labels
    /// are, so the narrow top and bottom of the disc hold them.
    var label: CGFloat {
        width * 0.16
    }
}

#Preview {
    ComplicationDisc { scale in
        VStack(spacing: scale.width * -0.03) {
            Text(verbatim: "Golden")
                .font(.system(size: scale.label, weight: .semibold))
            Text(verbatim: "6:05")
                .font(.system(size: scale.reading, weight: .semibold, design: .rounded))
        }
    }
    .frame(width: 50, height: 50)
    .padding()
    .background(.black)
    .environment(\.colorScheme, .dark)
}
