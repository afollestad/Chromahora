//
//  DetailRow.swift
//  Chromahora
//

import SwiftUI

/// What a row of the day's details reads: its name, the details beside it, and what VoiceOver
/// says for both.
struct DetailReading {
    let topic: DetailTopic
    let title: String
    /// Each on its own line, leaving out the unknown ones.
    let details: [String?]
    let label: String
}

/// A row of the day's details: the reading's name with its info button, then its details on
/// the trailing side, or under the name at accessibility sizes, where a column beside it would
/// break a time range in two. With a `date`, a tap anywhere but the info button scrolls the
/// timeline there, since a button nested in another's label never gets the tap. The phase under
/// way now is tinted with its color.
struct DetailRow<Leading: View>: View {
    let reading: DetailReading
    let date: Date?
    var hint = "Scrolls the timeline to it"
    var isCurrent = false
    var tint = Color.clear
    /// Scrolls the timeline to a time on the day.
    let onFocus: (Date) -> Void
    let leading: Leading

    /// The column icons and swatches center in.
    private static var leadingWidth: CGFloat { 22 }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 0) {
            if isStacked {
                VStack(alignment: .leading, spacing: 2) {
                    heading
                    lines
                        .padding(.leading, Self.leadingWidth + 12)
                }
                Spacer(minLength: 0)
            } else {
                heading
                    // The name takes the width it needs first, so a phase keeps one line in the
                    // day panel's narrow column while its details wrap beside it.
                    .layoutPriority(1)
                Spacer(minLength: 8)
                lines
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        // A full-size target even for a single line.
        .frame(minHeight: 44)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 14)
                    .fill(tint.opacity(0.25))
            }
        }
        .contentShape(.rect(cornerRadius: 14))
        .onTapGesture {
            if let date {
                onFocus(date)
            }
        }
        .hoverEffect(.highlight, isEnabled: date != nil)
        .padding(.horizontal, 8)
    }

    private var isStacked: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var heading: some View {
        HStack(spacing: 12) {
            leading
                .frame(width: Self.leadingWidth)
                .accessibilityHidden(true)
            // The name, which VoiceOver reads the whole row from, with its info button.
            HStack(spacing: 0) {
                Text(reading.title)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityLabel(reading.label)
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                    .accessibilityValue(isCurrent ? Text("Now") : Text(verbatim: ""))
                    .modifier(FocusAction(date: date, hint: hint, onFocus: onFocus))
                InfoButton(topic: reading.topic)
            }
        }
    }

    private var lines: some View {
        VStack(alignment: isStacked ? .leading : .trailing, spacing: 1) {
            if isCurrent {
                Text("Now")
                    .font(.caption.weight(.semibold))
            }
            ForEach(Array(reading.details.compactMap(\.self).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.footnote.monospacedDigit())
            }
        }
        .multilineTextAlignment(isStacked ? .leading : .trailing)
        // The name's label already says it.
        .accessibilityHidden(true)
    }
}

/// Makes a row's name a button for assistive technologies when it has a time to scroll to.
private struct FocusAction: ViewModifier {
    let date: Date?
    let hint: String
    let onFocus: (Date) -> Void

    func body(content: Content) -> some View {
        if let date {
            content
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(hint)
                .accessibilityAction {
                    onFocus(date)
                }
        } else {
            content
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        DetailRow(
            reading: DetailReading(topic: .goldenHour, title: "Golden hour", details: ["6:38–7:42 AM", "1 hr, 4 min"], label: "Golden hour"),
            date: .now,
            isCurrent: true,
            tint: DayPhase.goldenHour.color,
            onFocus: { _ in },
            leading: Circle().fill(DayPhase.goldenHour.color).frame(width: 14, height: 14)
        )
        DetailRow(
            reading: DetailReading(topic: .moonPhase, title: "Waxing crescent", details: ["31% illuminated"], label: "Waxing crescent"),
            date: nil,
            onFocus: { _ in },
            leading: Image(systemName: "moonphase.waxing.crescent")
        )
    }
    .padding(.vertical)
    .background(DayPhase.night.color)
}
