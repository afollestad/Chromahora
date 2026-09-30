//
//  PlaceSearchSheet.swift
//  Chromahora
//

import SwiftUI

/// What the location sheet needs from the app: the search and recent places built once for
/// every window, and how to show a place. Passed down from `ContentView`, so previews and
/// snapshots can hand in mocks.
struct PlaceChooser {
    let search: any PlaceSearch
    let recents: RecentPlaces
    /// Shows days for a chosen place, or for the device's again when nil.
    let choose: (Place?) -> Void

    /// A mock search and recents kept in memory, which choose nothing.
    static var preview: PlaceChooser {
        PlaceChooser(search: MockPlaceSearch(), recents: RecentPlaces(defaults: nil)) { _ in }
    }
}

/// Chooses where the times are for: the device's own place, a recent one, or anywhere Apple
/// Maps can find. The title opens it.
struct PlaceSearchSheet: View {
    let place: Place?
    let deviceName: String?
    let chooser: PlaceChooser

    /// How long typing pauses before a search. A quarter second is about the gap between a steady
    /// typist's keystrokes, so a search goes out once a word is typed rather than for each letter.
    private static let typingPause: Duration = .milliseconds(250)
    private static let settings = URL(string: UIApplication.openSettingsURLString)

    @State private var query: String
    /// Bumped by Search after a failure, so the same query is asked again.
    @State private var searchAttempt = 0
    @State private var suggestions: [PlaceSuggestion] = []
    /// The query `suggestions` answer, so "no results" shows only for a search that finished.
    @State private var answeredQuery: String?
    @State private var searchFailure: String?
    /// The suggestion being looked up, which a task follows so dismissing the sheet cancels it.
    @State private var pending: PlaceSuggestion?
    /// Why the last suggestion looked up couldn't be chosen, beside that suggestion's id.
    @State private var lookupFailure: (id: String, message: String)?
    /// The first search runs at once, so a query the sheet opens with doesn't wait.
    @State private var isFirstSearch = true
    /// The query Search was pressed for before its suggestions arrived, whose first suggestion is
    /// chosen when they do, rather than the first of the last query's.
    @State private var submittedQuery: String?
    /// Set once the sheet chooses or closes, so a lookup finishing while it closes can't choose.
    @State private var isFinished = false
    @Environment(\.dismiss) private var dismiss

    init(place: Place?, deviceName: String?, chooser: PlaceChooser, query: String = "") {
        self.place = place
        self.deviceName = deviceName
        self.chooser = chooser
        _query = State(initialValue: query)
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    currentLocation
                    recents
                } else {
                    results
                }
                Section {
                } footer: {
                    // Centered, since a footer's inset lines up with rows this empty section doesn't have.
                    AppleMapsCredit()
                        .frame(maxWidth: .infinity)
                }
            }
            .overlay {
                if showsNoResults {
                    ContentUnavailableView.search(text: trimmedQuery)
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        isFinished = true
                        pending = nil
                        dismiss()
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Town, park or landmark")
            // Place names aren't dictionary words, and a correction committed by Search would search for another place.
            .autocorrectionDisabled()
            .onSubmit(of: .search) {
                submit()
            }
            // Editing asks for a new search, so a pressed Search or a tapped suggestion no longer stands.
            .onChange(of: trimmedQuery) {
                submittedQuery = nil
                pending = nil
            }
            .task(id: SearchKey(query: query, attempt: searchAttempt)) {
                await search()
            }
            .task(id: pending?.id) {
                await lookUpPending()
            }
        }
        // Once a drag turns the bar dark, the title passes a white foreground and tint into what it
        // presents. It takes `Color.primary`, since `.primary` is a level of that white.
        .foregroundStyle(Color.primary)
        .tint(.accentColor)
    }

    private var currentLocation: some View {
        Section {
            PlaceRow(
                title: "Current Location",
                subtitle: currentLocationNote,
                glyph: isPlaceChosen ? "location" : place?.glyph ?? "location.slash",
                // Nothing places the device without location, so there's nothing to have selected.
                isSelected: place != nil && !isPlaceChosen
            ) {
                choose(nil)
            }
            if needsLocation, let settings = Self.settings {
                Link("Use Your Location in Settings", destination: settings)
                    // The sheet's primary foreground would otherwise make the link read as text.
                    .foregroundStyle(.tint)
            }
        }
    }

    @ViewBuilder
    private var recents: some View {
        if !chooser.recents.places.isEmpty {
            Section {
                ForEach(chooser.recents.places, id: \.self) { recent in
                    PlaceRow(title: recent.title(deviceName: nil), subtitle: recent.note, isSelected: recent == place) {
                        choose(recent)
                    }
                }
            } header: {
                HStack {
                    Text("Recent")
                    Spacer()
                    Button("Clear") {
                        chooser.recents.clear()
                    }
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Clear Recent Places")
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        if let searchFailure {
            Section {
                Text(searchFailure)
                    .foregroundStyle(.secondary)
            }
        } else {
            Section {
                if suggestions.isEmpty, answeredQuery != trimmedQuery {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
                ForEach(suggestions) { suggestion in
                    PlaceRow(
                        title: suggestion.title,
                        subtitle: lookupFailure?.id == suggestion.id ? lookupFailure?.message : suggestion.subtitle,
                        isFailure: lookupFailure?.id == suggestion.id,
                        isLoading: pending?.id == suggestion.id
                    ) {
                        submittedQuery = nil
                        pending = suggestion
                    }
                }
            }
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isPlaceChosen: Bool {
        if case .chosen = place?.source { true } else { false }
    }

    /// Whether only the time zone places the device, or nothing does, which usually means
    /// location is off for the app.
    private var needsLocation: Bool {
        switch place?.source {
        case nil, .timeZone: true
        case .device, .chosen: false
        }
    }

    private var showsNoResults: Bool {
        !trimmedQuery.isEmpty && answeredQuery == trimmedQuery && suggestions.isEmpty && searchFailure == nil
    }

    /// Where the current location is: the device's town, how its time zone stands in, or that
    /// nothing places it. While a place is chosen, the device's own isn't on hand.
    private var currentLocationNote: String? {
        guard !isPlaceChosen else {
            return nil
        }
        guard let place else {
            return "Turn on location to use it"
        }
        return place.note ?? deviceName
    }

    /// Searches for `query` once typing pauses, keeping the last suggestions on screen until
    /// the new ones arrive.
    private func search() async {
        let query = trimmedQuery
        let waits = !isFirstSearch
        isFirstSearch = false
        guard !query.isEmpty else {
            suggestions = []
            answeredQuery = nil
            searchFailure = nil
            return
        }
        if waits {
            try? await Task.sleep(for: Self.typingPause)
            guard !Task.isCancelled else {
                return
            }
        }
        // Unanswered again, so a retry shows the spinner rather than the last failure or "No Results".
        answeredQuery = nil
        searchFailure = nil
        do {
            let found = try await chooser.search.suggestions(for: query)
            guard !Task.isCancelled else {
                return
            }
            suggestions = found
            if found.isEmpty {
                AccessibilityNotification.Announcement("No results for \(query)").post()
            }
        } catch {
            guard !Task.isCancelled else {
                return
            }
            suggestions = []
            searchFailure = Self.unreachable
            AccessibilityNotification.Announcement(Self.unreachable).post()
        }
        answeredQuery = query
        lookupFailure = nil
        if submittedQuery == query {
            submittedQuery = nil
            pending = suggestions.first
        }
    }

    /// Chooses the first suggestion for the query, once there are any. After a failure, Search
    /// asks again.
    private func submit() {
        let query = trimmedQuery
        guard !query.isEmpty else {
            return
        }
        if answeredQuery == query, searchFailure == nil {
            pending = suggestions.first
        } else {
            submittedQuery = query
            if searchFailure != nil {
                searchAttempt += 1
            }
        }
    }

    /// Looks up the suggestion tapped, and chooses it once found.
    private func lookUpPending() async {
        guard let suggestion = pending else {
            return
        }
        lookupFailure = nil
        do {
            let found = try await chooser.search.place(for: suggestion)
            guard !Task.isCancelled else {
                return
            }
            choose(found)
        } catch {
            guard !Task.isCancelled else {
                return
            }
            let message = Self.message(for: error)
            lookupFailure = (suggestion.id, message)
            pending = nil
            AccessibilityNotification.Announcement(message).post()
        }
    }

    private func choose(_ place: Place?) {
        guard !isFinished else {
            return
        }
        isFinished = true
        pending = nil
        if let place {
            chooser.recents.add(place)
        }
        chooser.choose(place)
        dismiss()
    }

    private static func message(for error: any Error) -> String {
        switch error as? PlaceSearchError {
        case .noTimeZone:
            "Chromahora can't tell the time zone there. Try a nearby town."
        case .notFound:
            "Apple Maps can't find this place anymore. Try another."
        case nil:
            unreachable
        }
    }

    private static let unreachable = "Couldn't reach Apple Maps. Check your connection and try again."
}

/// What restarts a search: a new query, or Search pressed again after a failure.
private struct SearchKey: Equatable {
    let query: String
    let attempt: Int
}

/// A place in the sheet's list, which chooses it: its name, a note under it, and whether it's
/// the one shown.
private struct PlaceRow: View {
    let title: String
    var subtitle: String?
    var glyph: String?
    var isSelected = false
    var isFailure = false
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let glyph {
                    Image(systemName: glyph)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                // Colors rather than levels, which a list's button would take from its tint.
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                    // Apple Maps suggests some places, like Mount Everest, with no subtitle, and an
                    // empty line would hold the title above the row's middle.
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(isFailure ? Color.red : Color.secondary)
                    }
                }
                Spacer(minLength: 0)
                if isLoading {
                    ProgressView()
                        .accessibilityHidden(true)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isLoading ? Text("Loading") : Text(verbatim: ""))
    }
}

/// The Apple Maps mark and a link to its terms, since the suggestions and the device's town
/// come from Apple Maps.
private struct AppleMapsCredit: View {
    private static let terms = URL(string: "https://www.apple.com/legal/internet-services/maps/terms-en.html")

    var body: some View {
        // Stacked when the largest text sizes leave no room beside the mark for the whole link.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                credit
            }
            VStack(spacing: 4) {
                credit
            }
        }
        // The footer styles only its text, so the link would keep the body size, and the sheet's
        // primary foreground would outweigh the footer's gray.
        .font(.footnote)
        .foregroundStyle(Color.secondary)
    }

    @ViewBuilder
    private var credit: some View {
        Text("\(Image(systemName: "apple.logo")) Maps")
            .accessibilityLabel("Apple Maps")
        if let terms = Self.terms {
            Link("Terms of Use", destination: terms)
                .underline()
        }
    }
}

#Preview("Recents") {
    let chooser = PlaceChooser(
        search: MockPlaceSearch(),
        recents: RecentPlaces(defaults: nil, places: [MockPlaceSearch.kyoto, MockPlaceSearch.reykjavik])
    ) { _ in }
    PlaceSearchSheet(place: MockPlaceProvider.sanFrancisco, deviceName: "San Francisco", chooser: chooser)
}

#Preview("Results") {
    PlaceSearchSheet(place: MockPlaceSearch.kyoto, deviceName: nil, chooser: .preview, query: "Yo")
}

#Preview("Approximate") {
    PlaceSearchSheet(
        place: Place(latitude: 34.1, longitude: -118.2, source: .timeZone("America/Los_Angeles")),
        deviceName: nil,
        chooser: .preview
    )
}
