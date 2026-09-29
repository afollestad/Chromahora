//
//  MoonGlyph.swift
//  Chromahora
//

import SwiftUI
import WidgetKit

/// The moon as it looks, drawn rather than taken from the phase symbols: a dim disk with its lit
/// part on top, as much of it as `illumination` says. The symbols fill the shadow, which in light
/// text over a night sky glows and reads the phase inverted, and their layers overlap, so a
/// tinted Home Screen, which keeps only opacity, would draw every phase as a full disk.
struct MoonGlyph: View {
    /// Nil for a phase the app doesn't know.
    let phase: MoonPhase?
    /// The share of the disk lit, from 0 to 1. Nil takes the phase's usual share.
    let illumination: Double?

    @ScaledMetric private var size: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    /// `size` is the disk's diameter at the default text size, and scales with `textStyle`.
    init(phase: MoonPhase?, illumination: Double?, size: CGFloat, relativeTo textStyle: Font.TextStyle) {
        self.phase = phase
        self.illumination = illumination
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
    }

    var body: some View {
        Group {
            if let lit = illumination ?? phase?.usualIllumination {
                // Over a light background the disk is dark and the lit part white, like the moon in
                // a dark sky. Otherwise both are the text's own color, the disk faint: in dark text
                // that's white, and on a tinted Home Screen only opacity survives.
                let isLight = colorScheme == .light && renderingMode == .fullColor
                ZStack {
                    Circle()
                        .fill(isLight ? AnyShapeStyle(.black.opacity(0.7)) : AnyShapeStyle(.primary.opacity(0.3)))
                    LitPart(illumination: lit, isWaxing: phase?.isWaxing ?? true)
                        .fill(isLight ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                }
                .frame(width: size, height: size)
            } else {
                Image(systemName: "moon.fill")
                    .font(.system(size: size))
            }
        }
        // It only repeats the phase named beside it.
        .accessibilityHidden(true)
    }
}

/// The lit part of the disk: the rim on the lit side, closed by the terminator, a half ellipse
/// that bulges toward the lit side in a crescent and away from it past half.
private struct LitPart: Shape {
    let illumination: Double
    /// Lit on the right, as a waxing moon is seen from the northern hemisphere.
    let isWaxing: Bool

    /// Places a cubic curve's control points to approximate a quarter of an ellipse.
    private static let kappa = 0.5523

    func path(in rect: CGRect) -> Path {
        let lit = min(max(illumination, 0), 1)
        guard lit > 0 else {
            return Path()
        }
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let top = CGPoint(x: center.x, y: center.y - radius)
        let bottom = CGPoint(x: center.x, y: center.y + radius)
        // Toward the lit side in a crescent, away from it past half.
        let bulge = radius * (1 - 2 * lit)

        var path = Path()
        path.move(to: top)
        path.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        let middle = CGPoint(x: center.x + bulge, y: center.y)
        path.addCurve(
            to: middle,
            control1: CGPoint(x: center.x + bulge * Self.kappa, y: bottom.y),
            control2: CGPoint(x: middle.x, y: center.y + radius * Self.kappa)
        )
        path.addCurve(
            to: top,
            control1: CGPoint(x: middle.x, y: center.y - radius * Self.kappa),
            control2: CGPoint(x: center.x + bulge * Self.kappa, y: top.y)
        )
        path.closeSubpath()
        guard !isWaxing else {
            return path
        }
        return path.applying(CGAffineTransform(translationX: 2 * center.x, y: 0).scaledBy(x: -1, y: 1))
    }
}

private extension MoonPhase {
    /// Lit on the right, as the moon is from new to full, seen from the northern hemisphere.
    var isWaxing: Bool {
        switch self {
        case .new, .waxingCrescent, .firstQuarter, .waxingGibbous, .full: true
        case .waningGibbous, .lastQuarter, .waningCrescent: false
        }
    }

    /// The share lit through the middle of the phase, for a day that doesn't say.
    var usualIllumination: Double {
        switch self {
        case .new: 0
        case .waxingCrescent, .waningCrescent: 0.25
        case .firstQuarter, .lastQuarter: 0.5
        case .waxingGibbous, .waningGibbous: 0.75
        case .full: 1
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
            HStack {
                ForEach(MoonPhase.allCases, id: \.self) { phase in
                    MoonGlyph(phase: phase, illumination: nil, size: 28, relativeTo: .title)
                }
            }
            .padding()
            .background(scheme == .light ? DayPhase.daylight.color : DayPhase.night.color)
            .environment(\.colorScheme, scheme)
        }
    }
}
