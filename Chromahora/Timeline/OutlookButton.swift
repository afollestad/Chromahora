//
//  OutlookButton.swift
//  Chromahora
//

import SwiftUI

/// A rated phase label on the timeline, which opens a popover with its session's outlook, so
/// the timeline says why it rates as it does without a trip to the details. The target is the
/// capsule alone, since neighboring labels stack closer than a taller one would leave apart.
struct OutlookButton<Label: View>: View {
    let session: OutlookSession
    @ViewBuilder let label: Label

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            label
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .trailing) {
            OutlookSessionDetails(session: session)
                .popoverPadding()
                // Stops growing at accessibility1, like the timeline's labels and the weather popover.
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .popoverContent()
        }
    }
}

#Preview {
    let session = PhotoOutlook.sessions(on: .mock(), hours: SkyHour.mock())[2]
    OutlookButton(session: session) {
        Text("Golden hour · \(session.rating.title)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular.interactive(), in: Capsule())
    }
    .padding()
    .background(DayPhase.goldenHour.color)
}
