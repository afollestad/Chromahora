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
/// the trailing side, or under the name at accessibility sizes and on the watch, where a column
/// beside it would break a time range in two. With a `date` and a timeline to scroll, a tap
/// anywhere but the info button scrolls it there, since a button nested in another's label never
/// gets the tap. The phase under way now is tinted with its color.
struct DetailRow<Leading: View>: View {
    let reading: DetailReading
    let date: Date?
    var hint = "Scrolls the timeline to it"
    var isCurrent = false
    var tint = Color.clear
    /// Scrolls the timeline to a time on the day. Nil without a timeline, as on the watch.
    let onFocus: ((Date) -> Void)?
    let leading: Leading

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 0) {
            if isStacked {
                VStack(alignment: .leading, spacing: 2) {
                    heading
                    lines
                        .padding(.leading, DetailMetrics.leadingWidth + DetailMetrics.leadingSpacing)
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
        .padding(.leading, DetailMetrics.innerLeading)
        .padding(.trailing, DetailMetrics.innerTrailing)
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
            if let focusDate {
                onFocus?(focusDate)
            }
        }
        #if os(iOS)
        .hoverEffect(.highlight, isEnabled: focusDate != nil)
        #endif
        .padding(.horizontal, DetailMetrics.margin)
    }

    /// The time a tap scrolls the timeline to, when there's one to scroll.
    private var focusDate: Date? {
        onFocus == nil ? nil : date
    }

    private var isStacked: Bool {
        #if os(watchOS)
        true
        #else
        dynamicTypeSize.isAccessibilitySize
        #endif
    }

    private var heading: some View {
        HStack(spacing: DetailMetrics.leadingSpacing) {
            leading
                .frame(width: DetailMetrics.leadingWidth)
                .accessibilityHidden(true)
            // The name, which VoiceOver reads the whole row from, with its info button.
            HStack(spacing: 0) {
                Text(reading.title)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityLabel(reading.label)
                    .accessibilityAddTraits(isCurrent ? .isSelected : [])
                    .accessibilityValue(isCurrent ? Text("Now") : Text(verbatim: ""))
                    .modifier(FocusAction(date: focusDate, hint: hint) { onFocus?($0) })
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

/// How a row spaces its content, tighter on the watch, whose width barely holds a name and its
/// info button beside the leading column.
enum DetailMetrics {
    #if os(watchOS)
    /// The column icons and swatches center in.
    static let leadingWidth: CGFloat = 18
    /// Between that column and the name.
    static let leadingSpacing: CGFloat = 8
    /// Inside the current phase's tint.
    static let innerLeading: CGFloat = 6
    static let innerTrailing: CGFloat = 6
    /// Outside the tint, on both sides.
    static let margin: CGFloat = 4
    #else
    static let leadingWidth: CGFloat = 22
    static let leadingSpacing: CGFloat = 12
    static let innerLeading: CGFloat = 8
    static let innerTrailing: CGFloat = 12
    static let margin: CGFloat = 8
    #endif

    /// Where a row's leading column starts, which section headings line up with.
    static var contentInset: CGFloat {
        margin + innerLeading
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
