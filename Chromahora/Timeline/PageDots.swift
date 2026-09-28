//
//  PageDots.swift
//  Chromahora
//

import SwiftUI

/// Which of `DayPager`'s panes is on screen, as a dot for each under the sources button. Too
/// small to tap, so a swipe pages and VoiceOver adjusts it.
struct PageDots: View {
    /// How far below the sources button's frame the dots hang, into its padding and the home
    /// indicator's margin, so they add nothing to the bar's height. It leaves 9 pt between the
    /// capsule and the dots.
    static let offset: CGFloat = 9

    let pane: DayPager.Pane
    /// The sources button's scheme, so the dots contrast with the sky as it does.
    let scheme: ColorScheme
    let onSelect: (DayPager.Pane) -> Void

    private let panes = DayPager.Pane.allCases

    var body: some View {
        HStack(spacing: 7) {
            ForEach(panes, id: \.self) { item in
                Circle()
                    .fill(Color.primary.opacity(item == pane ? 1 : 0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .environment(\.colorScheme, scheme)
        .accessibilityElement()
        .accessibilityLabel("Page")
        .accessibilityValue("\(pane.title), \(index + 1) of \(panes.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment where index + 1 < panes.count:
                onSelect(panes[index + 1])
            case .decrement where index > 0:
                onSelect(panes[index - 1])
            default:
                break
            }
        }
    }

    private var index: Int {
        panes.firstIndex(of: pane) ?? 0
    }
}

#Preview {
    HStack(spacing: 24) {
        PageDots(pane: .timeline, scheme: .light) { _ in }
            .padding()
            .background(DayPhase.daylight.color)
        PageDots(pane: .details, scheme: .dark) { _ in }
            .padding()
            .background(DayPhase.night.color)
    }
}
