//
//  InfoButton.swift
//  Chromahora
//

import SwiftUI

/// An info button beside the name of a row of the day's details, opening a popover on what the
/// row reads and how a photographer uses it.
struct InfoButton: View {
    let topic: DetailTopic

    /// How far the target reaches past the icon on each side, which makes it about 44 pt square
    /// at the default size without spacing the icon away from the title.
    private static let reach: CGFloat = 13
    /// The space between the icon and the popover's arrow.
    private static let arrowGap: CGFloat = 6

    @State private var isPresented = false
    /// Whether the icon sits in the upper half of the list's visible area, so the popover opens
    /// below it rather than above.
    @State private var isInUpperHalf = true

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.footnote)
                // Laid out at the icon's size just past the title, so it reads as the title's own,
                // while the target reaches over the title's end, the space beyond and the row's margins.
                .contentShape(.rect.inset(by: -Self.reach))
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel("About \(topic.title)")
        .onGeometryChange(for: Bool.self) { proxy in
            // The list's visible area, in the icon's own coordinates.
            guard let visible = proxy.bounds(of: .scrollView), visible.height > 0 else {
                return true
            }
            return proxy.size.height / 2 - visible.minY < visible.height / 2
        } action: { isInUpperHalf in
            self.isInUpperHalf = isInUpperHalf
        }
        // Anchored on the icon alone, so the arrow points at its center, but a little taller, so
        // the arrow stops short of it. The padding is taken back after, leaving the layout alone.
        .padding(.vertical, Self.arrowGap)
        // Below or above, never beside, where the popover would be squeezed into what's left of
        // the width and cut its text off. The edge is the popover's own, where its arrow sits.
        .popover(isPresented: $isPresented, arrowEdge: isInUpperHalf ? .top : .bottom) {
            TopicDetails(topic: topic)
                .presentationCompactAdaptation(.popover)
        }
        .padding(.vertical, -Self.arrowGap)
        .padding(.leading, 5)
    }
}

/// The popover's content: what the reading is, then how to use it.
private struct TopicDetails: View {
    let topic: DetailTopic

    var body: some View {
        // Sized by a hidden copy of the text, since a scroll view alone has no height to give the
        // popover, which then never shows. The copy asks for the text's full height and gives way
        // where the room above or below the icon is shorter, as at large sizes, so the text on
        // top scrolls there rather than truncating.
        content
            .hidden()
            .accessibilityHidden(true)
            .overlay {
                ScrollView {
                    content
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        // Stops growing at accessibility1, like the rest of the details. Past it, the text would
        // break to a word or two a line in this width.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(topic.title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(topic.meaning)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("For photographers")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(topic.photographyTip)
            }
        }
        .font(.subheadline)
        // `Color.primary` rather than `.primary`, which a dark bar's items would pass down as white.
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
        // `SourcesButton`'s popover width, so sentences wrap evenly.
        .frame(width: 280, alignment: .leading)
        .padding()
    }
}

#Preview {
    InfoButton(topic: .goldenHour)
}
