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

    /// How far below the top of the visible area to sample the phase that
    /// decides the navigation bar's color scheme, roughly the title's position.
    private let barProbeOffset: CGFloat = 64

    @State private var phaseUnderBar: DayPhase = .night
    @State private var isChoosingDay = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack {
                    SkyGradient(day: day)
                    DayTimelineOverlay(day: day, now: now)
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
            .background(DayPhase.night.color)
            .ignoresSafeArea()
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
            .onScrollGeometryChange(for: DayPhase.self) { geometry in
                let y = geometry.visibleRect.minY + barProbeOffset
                return day.phase(at: day.dayStart.addingTimeInterval(y / contentHeight * day.duration))
            } action: { _, phase in
                phaseUnderBar = phase
            }
            .toolbarColorScheme(phaseUnderBar.isDark ? .dark : .light, for: .navigationBar)
            .navigationTitle("Chromahora")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Chromahora")
                            .font(.headline)
                        Text(day.dayStart, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: Capsule())
                    .accessibilityElement(children: .combine)
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

    /// The time the view centers on: now when it falls on this day, otherwise the middle of daylight.
    private var focusDate: Date {
        if day.contains(now) {
            return now
        }
        return day.segments.first { $0.phase == .daylight }?.midpoint
            ?? day.dayStart.addingTimeInterval(day.duration / 2)
    }
}

#Preview {
    @Previewable @State var selectedDate = Date.now
    NavigationStack {
        DayTimeline(day: .mock(for: selectedDate), now: .now, selectedDate: $selectedDate)
    }
}
