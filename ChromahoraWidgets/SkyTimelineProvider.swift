//
//  SkyTimelineProvider.swift
//  ChromahoraWidgets
//

import WidgetKit

/// Every widget's timeline, from `SkyLoader.live`. WidgetKit doesn't say which thread calls it,
/// so it's nonisolated, hands the loading to the main actor, and takes back only Sendable values.
nonisolated struct SkyTimelineProvider: TimelineProvider {
    /// Whether the widget shows weather, which only then is asked for, so widgets without it
    /// spend none of the quota.
    let showsWeather: Bool

    func placeholder(in context: Context) -> SkyEntry {
        SkyEntry(date: .now, state: .loaded(.preview(at: .now)))
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (SkyEntry) -> Void) {
        // The gallery shows a sample at once rather than wait on a fix and a fetch.
        guard !context.isPreview else {
            completion(placeholder(in: context))
            return
        }
        Task { @MainActor in
            let now = Date.now
            let content = await SkyLoader.live.content(now: now, withWeather: showsWeather)
            completion(SkyEntry(date: now, state: content.map { .loaded($0) } ?? .unavailable))
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SkyEntry>) -> Void) {
        Task { @MainActor in
            let timeline = await SkyLoader.live.timeline(now: .now, withWeather: showsWeather)
            completion(Timeline(entries: timeline.entries, policy: .after(timeline.reload)))
        }
    }
}
