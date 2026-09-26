//
//  SnapshotTestSupport.swift
//  ChromahoraTests
//

import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// The simulator every baseline is recorded on. Screen size, safe areas and the
/// system's glass rendering differ between devices, so a baseline only holds on
/// this one. The scripts default to it; change them together.
let snapshotDeviceName = "iPhone 18 Pro"

/// `snapshotDeviceName`'s hardware model. Checked instead of the name, since
/// parallel test runs, like Xcode's default, use clones named "Clone 1 of …".
private let snapshotModelIdentifier = "iPhone19,2"

/// `0.99` for both knobs is the Delta-E threshold SnapshotTesting documents as
/// matching the human eye, with up to 1% of pixels allowed past it. Glass and the
/// sky gradient render on the GPU, where a bit-exact `1.0` would fail on sub-visible
/// rounding between Macs. Override per call site rather than tightening these,
/// since that drift would apply to every full-screen image at once.
let defaultPixelPrecision: Float = 0.99
let defaultPerceptualPrecision: Float = 0.99

/// Below the device's 3x to keep full-screen baselines small, while keeping every
/// hairline and glyph edge distinct.
private let snapshotScale: CGFloat = 2

/// Long enough for `task`, the scroll to the focus time, and the safe area
/// measurement to land after a screen's first frame.
private let settleTimeout: Duration = .seconds(3)
private let settleInterval: Duration = .milliseconds(100)

/// Renders `view` full screen in its own window on the host app's scene, waits for it
/// to settle, and compares it against the stored baseline.
///
/// The window matters. `drawHierarchy` is what captures Liquid Glass and other backdrop
/// effects, which `layer.render(in:)` leaves blank, and a full-screen window on the scene
/// gets the device's real safe area. The status bar, Dynamic Island and home indicator
/// draw outside the app, so they never appear in a baseline.
@MainActor
func assertScreenSnapshot<V: View>(
    of view: V,
    named name: String? = nil,
    precision: Float = defaultPixelPrecision,
    perceptualPrecision: Float = defaultPerceptualPrecision,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) async {
    let sourceLocation = SourceLocation(
        fileID: "\(fileID)", filePath: "\(filePath)", line: Int(line), column: Int(column)
    )
    let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
    guard model == snapshotModelIdentifier else {
        Issue.record(
            """
            Snapshots are recorded on \(snapshotDeviceName) (\(snapshotModelIdentifier)), not \(model ?? "an unknown device"). \
            Run them through ./scripts/snapshots.sh.
            """,
            sourceLocation: sourceLocation
        )
        return
    }
    // Time labels format with the process locale rather than the SwiftUI environment,
    // so the locale can't be pinned from here; the scripts launch tests with it.
    guard Locale.current.language.languageCode == .english, Locale.current.region == .unitedStates else {
        Issue.record(
            "Snapshots are recorded in en_US, not \(Locale.current.identifier). Run them through ./scripts/snapshots.sh.",
            sourceLocation: sourceLocation
        )
        return
    }
    guard let scene = UIApplication.shared.connectedScenes.lazy.compactMap({ $0 as? UIWindowScene }).first else {
        Issue.record("Snapshots need the host app's window scene.", sourceLocation: sourceLocation)
        return
    }

    let window = UIWindow(windowScene: scene)
    window.frame = scene.effectiveGeometry.coordinateSpace.bounds
    // Above the host app's own window, which keeps running underneath.
    window.windowLevel = .alert + 1
    window.rootViewController = UIHostingController(
        rootView: view
            .transaction { $0.animation = nil }
            .environment(\.dynamicTypeSize, .large)
    )
    window.isHidden = false
    defer {
        window.isHidden = true
        window.rootViewController = nil
    }

    let image = await settledImage(of: window)
    assertSnapshot(
        of: image,
        as: .image(precision: precision, perceptualPrecision: perceptualPrecision),
        named: name,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
}

/// Captures `window` until two captures in a row match, so the baseline shows the
/// screen after its first-frame work has landed. A screen that never settles, such
/// as one with a spinner, yields its last capture at the timeout.
@MainActor
private func settledImage(of window: UIWindow) async -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = snapshotScale
    // The renderer otherwise picks 16-bit Display P3 on this device. SnapshotTesting compares
    // 8-bit pixels, and reports most of a 16-bit image as mismatched even when it's identical.
    format.preferredRange = .standard
    let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
    func capture() -> UIImage {
        renderer.image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    var image = capture()
    var previous = image.pngData()
    let deadline = ContinuousClock.now + settleTimeout
    while ContinuousClock.now < deadline {
        try? await Task.sleep(for: settleInterval)
        image = capture()
        let data = image.pngData()
        if data == previous {
            break
        }
        previous = data
    }
    return image
}
