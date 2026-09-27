//
//  DebugDrawer.swift
//  Chromahora
//

#if DEBUG
import SwiftUI

extension View {
    /// Adds the debug drawer, opened by swiping in from the right edge. Without
    /// settings, as in previews and snapshot tests, the view is left alone.
    @ViewBuilder
    func debugDrawer(store: SolarDayStore, settings: DebugSettings?) -> some View {
        if let settings {
            modifier(DebugDrawer(store: store, settings: settings))
        } else {
            self
        }
    }
}

private struct DebugDrawer: ViewModifier {
    let store: SolarDayStore
    let settings: DebugSettings

    @State private var isOpen = false

    // The scrim and panel are inserted separately, since a transition only applies
    // to the view an `if` inserts, not to its descendants.
    func body(content: Content) -> some View {
        content
            .gesture(ScreenEdgeSwipe { setOpen(true) })
            .overlay {
                if isOpen {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { setOpen(false) }
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .trailing) {
                if isOpen {
                    panel
                        .transition(.move(edge: .trailing))
                }
            }
            .task {
                guard settings.opensPanelOnLaunch else {
                    return
                }
                // Presentations on the first frame don't render.
                try? await Task.sleep(for: .milliseconds(500))
                setOpen(true)
            }
    }

    private var panel: some View {
        DebugPanel(store: store, settings: settings) {
            setOpen(false)
        }
        // Leaves a strip of the app showing, so the drawer reads as dismissible.
        .containerRelativeFrame(.horizontal) { width, _ in
            min(340, width - 44)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(.trailing, 8)
        .gesture(
            DragGesture(minimumDistance: 20).onEnded { value in
                if value.translation.width > 60 {
                    setOpen(false)
                }
            }
        )
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { setOpen(false) }
    }

    private func setOpen(_ open: Bool) {
        withAnimation(.snappy) {
            isOpen = open
        }
    }
}

/// The drawer's controls, which later tools add sections to.
private struct DebugPanel: View {
    let store: SolarDayStore
    @Bindable var settings: DebugSettings
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Loading") {
                    Picker("Sun times", selection: $settings.providerMode) {
                        ForEach(DebugSettings.ProviderMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Button("Reload from scratch") {
                        store.discardLoadedDays()
                        store.reload()
                    }
                }

                Section {
                    Toggle("Override now", isOn: isOverridingNow)
                    if let override = settings.nowOverride {
                        DatePicker("Now", selection: nowOverride(defaultingTo: override))
                    }
                } header: {
                    Text("Time")
                } footer: {
                    Text("Also selects that day.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }

    private var isOverridingNow: Binding<Bool> {
        Binding {
            settings.nowOverride != nil
        } set: { isOn in
            setNow(isOn ? .now : nil)
        }
    }

    private func nowOverride(defaultingTo date: Date) -> Binding<Date> {
        Binding {
            settings.nowOverride ?? date
        } set: { newValue in
            setNow(newValue)
        }
    }

    private func setNow(_ date: Date?) {
        settings.nowOverride = date
        store.selectedDate = date ?? .now
    }
}

#Preview {
    Color.clear
        .debugDrawer(
            store: SolarDayStore(provider: MockSolarDayProvider()),
            settings: DebugSettings(arguments: ["DebugPanel": "YES"])
        )
}
#endif
