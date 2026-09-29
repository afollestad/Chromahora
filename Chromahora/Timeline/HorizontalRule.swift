//
//  HorizontalRule.swift
//  Chromahora
//

import SwiftUI

/// A horizontal line through the middle of its frame, for a stroke style to dash.
/// `Rectangle` would stroke both edges of its one-point frame.
struct HorizontalRule: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

#Preview {
    HorizontalRule()
        .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .frame(height: 1)
        .padding()
        .background(DayPhase.night.color)
}
