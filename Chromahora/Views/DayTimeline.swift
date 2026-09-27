//
//  DayTimeline.swift
//  Chromahora
//

import SwiftUI

/// A scrolling, top-to-bottom view of one day. `pointsPerHour` sets the zoom
/// level. The view opens centered on the current time when showing today, and
/// on the middle of daylight otherwise.
struct DayTimeline: View {
    let day: SolarDay
    let now: Date
    @Binding var selectedDate: Date
    var pointsPerHour: CGFloat = 72

    private let focusAnchorID = "focus"

    /// The sky's relative luminance where white and black text contrast with it
    /// equally is about 0.18. The bar turns dark below this range and light above
    /// it, so scrolling slowly across the crossover doesn't flicker the title.
    private static let darkBarLuminance = 0.17...0.19

    @State private var isBarDark = true
    @State private var skyBehindTitle = DayPhase.night.color
    @State private var safeAreaInsets = EdgeInsets()
    /// The timeline's top edge and the title's center, in global coordinates, which
    /// place the sky sample behind the title.
    @State private var timelineMinY: CGFloat = 0
    @State private var titleMidY: CGFloat = 0
    @State private var isChoosingDay = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack {
                    SkyGradient(day: day)
                    DayTimelineOverlay(day: day, now: now, safeAreaInsets: safeAreaInsets)
                        // Past accessibility1, even a shortened phase label wraps beside a marker
                        // on a 390pt-wide phone. Applied out here so the overlay's scaled
                        // spacing stops growing at the same size.
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                }
                .frame(height: contentHeight)
                .overlay(alignment: .top) {
                    // Invisible scroll target. The padding keeps its one-point
                    // frame at the focus time.
                    Color.clear
                        .frame(height: 1)
                        .id(focusAnchorID)
                        .padding(.top, contentHeight * day.fraction(of: focusDate))
                }
            }
            // Overscrolling past either end uncovers this, so each half continues the sky at
            // its end and the scrim runs on without a seam. The opaque sky covers it otherwise.
            .background {
                ZStack {
                    VStack(spacing: 0) {
                        SkyGradient.color(at: 0, in: day)
                        SkyGradient.color(at: 1, in: day)
                    }
                    RulerScrim(leadingInset: safeAreaInsets.leading)
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
            .ignoresSafeArea()
            // Measured outside `ignoresSafeArea`, since the scroll content sees no insets at all.
            .onGeometryChange(for: EdgeInsets.self) { proxy in
                proxy.safeAreaInsets
            } action: { insets in
                safeAreaInsets = insets
            }
            // The timeline extends past this frame by the top inset.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY - proxy.safeAreaInsets.top
            } action: { minY in
                timelineMinY = minY
            }
            .scrollEdgeEffectHidden()
            .onAppear {
                proxy.scrollTo(focusAnchorID, anchor: .center)
            }
            .onChange(of: day) {
                withAnimation {
                    proxy.scrollTo(focusAnchorID, anchor: .center)
                }
            }
            .onChange(of: selectedDate) {
                isChoosingDay = false
            }
            .onScrollGeometryChange(for: Color.self) { geometry in
                let y = geometry.visibleRect.minY + titleMidY - timelineMinY
                return SkyGradient.color(at: y / contentHeight, in: day)
            } action: { _, color in
                skyBehindTitle = color
                isBarDark = Self.prefersDarkBar(over: color, wasDark: isBarDark)
            }
            .toolbarColorScheme(isBarDark ? .dark : .light, for: .navigationBar)
            .navigationTitle("Chromahora")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TitlePill(day: day, skyColor: $skyBehindTitle)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.frame(in: .global).midY
                        } action: { midY in
                            titleMidY = midY
                        }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isChoosingDay = true
                    } label: {
                        Label("Choose day", systemImage: "calendar")
                    }
                    .accessibilityLabel("Choose day")
                    .accessibilityValue(Text(day.dayStart, format: .dateTime.weekday(.wide).month(.wide).day()))
                    .accessibilityHint("Opens a calendar to choose the day to show")
                    .popover(isPresented: $isChoosingDay, arrowEdge: .top) {
                        DayPicker(selection: $selectedDate) {
                            selectedDate = .now
                            withAnimation {
                                proxy.scrollTo(focusAnchorID, anchor: .center)
                            }
                        }
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
        }
    }

    private var contentHeight: CGFloat {
        pointsPerHour * day.duration / (60 * 60)
    }

    /// Whether the bar should be dark over `color`. Inside `darkBarLuminance` it keeps `wasDark`.
    static func prefersDarkBar(over color: Color, wasDark: Bool) -> Bool {
        let luminance = luminance(of: color)
        if luminance < darkBarLuminance.lowerBound {
            return true
        }
        if luminance > darkBarLuminance.upperBound {
            return false
        }
        return wasDark
    }

    /// Relative luminance as WCAG defines it, which weights green most because the eye is most sensitive to it.
    static func luminance(of color: Color) -> Double {
        let resolved = color.resolve(in: EnvironmentValues())
        return 0.2126 * Double(resolved.linearRed) + 0.7152 * Double(resolved.linearGreen) + 0.0722 * Double(resolved.linearBlue)
    }

    /// The time the view centers on: now when it falls on this day, otherwise the middle of daylight.
    private var focusDate: Date {
        if day.contains(now) {
            return now
        }
        return day.segments.first { $0.phase == .daylight }?.midpoint
            ?? day.dayStart.addingTimeInterval(day.duration / 2)
    }
}

/// The title and day on glass tinted with the sky behind it, so the glass carries
/// its backdrop's hue through the blended phases. It takes the color as a binding
/// so that only this view, not the whole timeline, redraws on each frame of a scroll.
private struct TitlePill: View {
    let day: SolarDay
    @Binding var skyColor: Color

    var body: some View {
        VStack(spacing: 1) {
            Text("Chromahora")
                .font(.headline)
            // Primary rather than secondary, which drops below 3:1 on the tinted glass.
            // The smaller, lighter font already ranks it below the title.
            Text(day.dayStart, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(skyColor.opacity(0.5)), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    @Previewable @State var selectedDate = Date.now
    NavigationStack {
        DayTimeline(day: .mock(for: selectedDate), now: .now, selectedDate: $selectedDate)
    }
}
