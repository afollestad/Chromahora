//
//  ScreenEdgeSwipe.swift
//  Chromahora
//

#if DEBUG
import SwiftUI
import UIKit

/// A swipe in from the screen's right edge. SwiftUI has no edge-anchored gesture,
/// and a drag gesture on a strip along the edge would steal the timeline's scrolls.
struct ScreenEdgeSwipe: UIGestureRecognizerRepresentable {
    let action: () -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Scroll views wait for the edge swipe to fail, so a swipe that starts at the
        /// edge opens the drawer rather than scrolling. Touches away from the edge fail it at once.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            otherGestureRecognizer.view is UIScrollView
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIScreenEdgePanGestureRecognizer {
        // There's no initializer that takes the edges.
        let recognizer = UIScreenEdgePanGestureRecognizer()
        recognizer.edges = .right
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIScreenEdgePanGestureRecognizer, context: Context) {
        if recognizer.state == .began {
            action()
        }
    }
}
#endif
