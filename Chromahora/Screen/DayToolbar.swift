//
//  DayToolbar.swift
//  Chromahora
//

import SwiftUI

/// The title and calendar button, shared by the timeline and its placeholders so they
/// stay put while a day loads, and so the calendar can leave a day that failed.
struct DayToolbar: ToolbarContent {
    let isLoading: Bool
    @Binding var skyColor: Color
    @Binding var selectedDate: Date
    let now: Date
    let onTitleMidY: (CGFloat) -> Void
    let onToday: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            TitlePill(date: selectedDate, isLoading: isLoading, skyColor: $skyColor)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).midY
                } action: { midY in
                    onTitleMidY(midY)
                }
        }

        ToolbarItem(placement: .primaryAction) {
            DayPickerButton(selection: $selectedDate, now: now, onToday: onToday)
        }
    }
}

/// The title and day on glass tinted with the sky behind it, so the glass carries
/// its backdrop's hue through the blended phases. It takes the color as a binding
/// so that only this view, not the whole timeline, redraws on each frame of a scroll.
private struct TitlePill: View {
    let date: Date
    /// Another day is on its way while the last one stays on screen.
    let isLoading: Bool
    @Binding var skyColor: Color

    var body: some View {
        VStack(spacing: 1) {
            Text("Chromahora")
                .font(.headline)
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .accessibilityHidden(true)
                }
                // Primary rather than secondary, which drops below 3:1 on the tinted glass.
                // The smaller, lighter font already ranks it below the title.
                Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.caption)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(skyColor.opacity(0.5)), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityValue(isLoading ? Text("Loading") : Text(verbatim: ""))
    }
}

/// Opens the day picker, and closes it once a day is chosen.
private struct DayPickerButton: View {
    @Binding var selection: Date
    let now: Date
    let onToday: () -> Void

    @State private var isChoosingDay = false

    var body: some View {
        Button {
            isChoosingDay = true
        } label: {
            Label("Choose day", systemImage: "calendar")
        }
        .accessibilityLabel("Choose day")
        .accessibilityValue(Text(selection, format: .dateTime.weekday(.wide).month(.wide).day()))
        .accessibilityHint("Opens a calendar to choose the day to show")
        .popover(isPresented: $isChoosingDay, arrowEdge: .top) {
            DayPicker(selection: $selection) {
                // `now`, not `.now`, so Today follows the debug drawer's clock.
                selection = now
                isChoosingDay = false
                onToday()
            }
            .presentationCompactAdaptation(.popover)
        }
        .onChange(of: selection) {
            isChoosingDay = false
        }
    }
}

#Preview {
    @Previewable @State var sky = DayPhase.daylight.color
    @Previewable @State var selectedDate = Date.now
    NavigationStack {
        DayPhase.daylight.color
            .ignoresSafeArea()
            .toolbar {
                DayToolbar(isLoading: true, skyColor: $sky, selectedDate: $selectedDate, now: .now, onTitleMidY: { _ in }, onToday: {})
            }
    }
}
