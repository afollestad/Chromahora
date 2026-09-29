//
//  DayToolbar.swift
//  Chromahora
//

import SwiftUI

/// The title, which names the place and opens the location sheet, and the calendar button,
/// shared by the timeline and its placeholders so they stay put while a day loads, and so
/// either can leave a day that failed. A wide window drops the button, since the day panel
/// shows the calendar.
struct DayToolbar: ToolbarContent {
    let isLoading: Bool
    @Binding var skyColor: Color
    @Binding var selectedDate: Date
    let now: Date
    /// The store's, whose zone reads the selected date.
    var calendar: Calendar = .current
    var place: Place?
    /// The town the device's place lies in, once found.
    var deviceName: String?
    let chooser: PlaceChooser
    var showsDayPicker = true
    let onTitleMidY: (CGFloat) -> Void
    let onToday: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            TitlePill(
                date: selectedDate,
                timeZone: calendar.timeZone,
                place: place,
                deviceName: deviceName,
                chooser: chooser,
                isLoading: isLoading,
                skyColor: $skyColor
            )
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).midY
            } action: { midY in
                onTitleMidY(midY)
            }
        }
        // The pill brings its own tinted glass, which the bar's glass behind a button would double.
        .sharedBackgroundVisibility(.hidden)

        // An `if` rather than `hidden(_:)`, which iOS doesn't offer for toolbar content.
        if showsDayPicker {
            ToolbarItem(placement: .primaryAction) {
                DayPickerButton(selection: $selectedDate, now: now, calendar: calendar, onToday: onToday)
            }
        }
    }
}

/// The place and day on glass tinted with the sky behind it, so the glass carries its
/// backdrop's hue through the blended phases, which opens the location sheet. It takes the
/// color as a binding, which only `SkyTintedGlass` reads, so each frame of a scroll across a
/// blend retints the glass without redrawing the pill or the timeline.
private struct TitlePill: View {
    let date: Date
    let timeZone: TimeZone
    let place: Place?
    let deviceName: String?
    let chooser: PlaceChooser
    /// Another day is on its way while the last one stays on screen.
    let isLoading: Bool
    @Binding var skyColor: Color

    @State private var isChoosingPlace = false

    var body: some View {
        Button {
            isChoosingPlace = true
        } label: {
            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    if let glyph = place?.glyph {
                        Image(systemName: glyph)
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                    Text(place?.title(deviceName: deviceName) ?? Place.unplacedTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .accessibilityHidden(true)
                }
                HStack(spacing: 4) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .accessibilityHidden(true)
                    }
                    // Primary rather than secondary, which drops below 3:1 on the tinted glass.
                    // The smaller, lighter font already ranks it below the title.
                    Text(date.dayTitle(in: timeZone))
                        .font(.caption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Capsule())
            .modifier(SkyTintedGlass(sky: $skyColor))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(spokenPlace), \(date.dayTitle(in: timeZone))")
        .accessibilityValue(isLoading ? Text("Loading") : Text(verbatim: ""))
        .accessibilityHint("Opens a search to choose where the times are for")
        // The bar holds its text to one size, so a long press shows it larger.
        .accessibilityShowsLargeContentViewer()
        .sheet(isPresented: $isChoosingPlace) {
            PlaceSearchSheet(place: place, deviceName: deviceName, chooser: chooser)
        }
    }

    /// The place as VoiceOver reads it, saying what the hidden glyph shows.
    private var spokenPlace: String {
        place?.spokenTitle(deviceName: deviceName) ?? Place.unplacedTitle
    }
}

/// The title pill's glass, tinted with the sky behind it.
private struct SkyTintedGlass: ViewModifier {
    @Binding var sky: Color

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.tint(sky.opacity(0.5)).interactive(), in: Capsule())
    }
}

/// Opens the day picker, and closes it once a day is chosen.
private struct DayPickerButton: View {
    @Binding var selection: Date
    let now: Date
    let calendar: Calendar
    let onToday: () -> Void

    @State private var isChoosingDay = false

    var body: some View {
        Button {
            isChoosingDay = true
        } label: {
            Label("Choose day", systemImage: "calendar")
        }
        .accessibilityLabel("Choose day")
        .accessibilityValue(selection.dayTitle(in: calendar.timeZone))
        .accessibilityHint("Opens a calendar to choose the day to show")
        .popover(isPresented: $isChoosingDay, arrowEdge: .top) {
            DayPicker(selection: $selection, calendar: calendar) {
                // `now`, not `.now`, so Today follows the debug drawer's clock.
                selection = now
                isChoosingDay = false
                onToday()
            }
            // Once a drag turns the bar dark, its items pass a white foreground and tint into
            // the popover, which sits over the sky below rather than the bar. It takes
            // `Color.primary`, since `.primary` is a level of that white.
            .foregroundStyle(Color.primary)
            .tint(.accentColor)
            .popoverContent()
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
                DayToolbar(
                    isLoading: true,
                    skyColor: $sky,
                    selectedDate: $selectedDate,
                    now: .now,
                    place: MockPlaceProvider.sanFrancisco,
                    deviceName: "San Francisco",
                    chooser: .preview,
                    onTitleMidY: { _ in },
                    onToday: {}
                )
            }
    }
}
