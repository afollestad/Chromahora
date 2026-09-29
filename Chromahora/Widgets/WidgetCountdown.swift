//
//  WidgetCountdown.swift
//  Chromahora
//

import SwiftUI

extension EnvironmentValues {
    /// Whether countdowns tick with the clock. Snapshots turn it off, so they read the entry's
    /// moment rather than the real one.
    @Entry var ticksCountdowns = true
}

/// The time left until `date`, in one rounded unit, as in "in 8 hours" or "in 35 minutes". The
/// system updates the text as it changes, so it needs no timeline entry of its own. Ticking, it
/// fills the width it's offered, so align its words with `multilineTextAlignment`, not a frame;
/// snapshots, which stop it ticking, can't show the difference.
struct WidgetCountdown: View {
    let date: Date
    /// The entry's moment, which a countdown that doesn't tick reads from.
    let now: Date
    @Environment(\.ticksCountdowns) private var ticks

    var body: some View {
        if ticks {
            Text(.currentDate, format: style)
        } else {
            Text(style.format(now))
        }
    }

    /// Hours or minutes, since seconds would tick distractingly, and days would round away hours that matter.
    private var style: SystemFormatStyle.DateReference {
        .reference(to: date, allowedFields: [.hour, .minute])
    }
}

#Preview {
    let now = Date.now
    VStack(alignment: .leading) {
        WidgetCountdown(date: now.addingTimeInterval(95 * 60), now: now)
        WidgetCountdown(date: now.addingTimeInterval(95 * 60), now: now)
            .environment(\.ticksCountdowns, false)
    }
}
