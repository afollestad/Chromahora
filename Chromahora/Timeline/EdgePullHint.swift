//
//  EdgePullHint.swift
//  Chromahora
//

import SwiftUI

/// Names the day a pull past one of the timeline's ends leads to, in the gap the pull opens
/// between the bar and the day's end. It grows in with the pull and pops once letting go
/// would page there, with a tap of haptics, so the push through the rubber band has a detent.
///
/// It reads the pull through a binding, so a pull redraws only the hint, not the timeline.
struct EdgePullHint: View {
    @Binding var pull: EdgePull?
    let day: SolarDay
    /// The insets the timeline's labels keep from each edge, which the gap starts past.
    let insets: EdgeInsets
    /// The room the timeline leaves between the bars and the day's ends at rest.
    let clearance: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let pull {
                capsule(for: pull)
                    // Centered in the gap, which grows as the pull moves the day's end away from the bar.
                    .frame(height: clearance + pull.distance)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: pull.edge == .top ? .top : .bottom)
            }
        }
        .padding(insets)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func capsule(for pull: EdgePull) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName(for: pull))
                .contentTransition(.symbolEffect(.replace))
            if let date = EdgePull.dayStart(beyond: pull.edge, of: day) {
                Text(day.dayText(date))
            }
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: Capsule())
        // The sky past the day's end continues its color there.
        .environment(\.colorScheme, SkyGradient.labelScheme(over: SkyGradient.color(at: pull.edge == .top ? 0 : 1, in: day)))
        // The labels' cap, so the capsule never outgrows them.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .scaleEffect(reduceMotion ? 1 : pull.isArmed ? 1.08 : 0.85 + 0.15 * pull.progress)
        .opacity(pull.progress)
        .animation(reduceMotion ? nil : .bouncy, value: pull.isArmed)
        .sensoryFeedback(.impact(weight: .light), trigger: pull.isArmed) { _, isArmed in
            isArmed
        }
    }

    private func symbolName(for pull: EdgePull) -> String {
        let chevron = pull.edge == .top ? "chevron.up" : "chevron.down"
        return pull.isArmed ? "\(chevron).circle.fill" : chevron
    }
}

#Preview {
    @Previewable @State var top: EdgePull? = EdgePull(edge: .top, distance: EdgePull.threshold)
    @Previewable @State var bottom: EdgePull? = EdgePull(edge: .bottom, distance: EdgePull.threshold / 2)
    let insets = EdgeInsets(top: 60, leading: 0, bottom: 34, trailing: 0)
    ZStack {
        SkyGradient(day: .mock())
            .ignoresSafeArea()
        EdgePullHint(pull: $top, day: .mock(), insets: insets, clearance: 24)
        EdgePullHint(pull: $bottom, day: .mock(), insets: insets, clearance: 24)
    }
}
