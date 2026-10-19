//
//  View+Popover.swift
//  Chromahora
//

import SwiftUI

extension View {
    /// Shows a popover's content as a popover on iPhone too, rather than a sheet, and keeps it
    /// centered on the popover's glass.
    ///
    /// iOS 27 can make a popover's host 13 pt longer than its glass along the arrow's axis,
    /// with the glass at the host's top-leading corner whichever edge the arrow is on. Centered
    /// in the host, content drifts 6.5 pt off the glass and crowds one edge. Pinned to that
    /// corner, it sits on the glass, and where the host matches the glass, nothing moves.
    func popoverContent() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .presentationCompactAdaptation(.popover)
    }

    /// Insets a popover's text from its glass. The default 16 pt crowds the first and last lines
    /// against the glass's large corners, as a credit under the text shows.
    func popoverPadding() -> some View {
        padding(20)
    }
}
