//
//  SnapshotTestSupport.swift
//  ChromahoraTests
//

import SnapshotTesting
import SwiftUI
import Testing
import UIKit

/// A simulator baselines are recorded on. Screen size, safe areas and the system's glass
/// rendering differ between devices, so a baseline only holds on its suite's device. The
/// scripts pin each suite to it; change them together.
struct SnapshotDevice: Sendable {
    let name: String
    /// The hardware model, checked instead of the name, since parallel test runs, like Xcode's
    /// default, use clones named "Clone 1 of …". `plutil -extract modelIdentifier raw` reads
    /// it from a device type's `profile.plist`, under `<name>.simdevicetype/Contents/Resources/`
    /// in `/Library/Developer/CoreSimulator/Profiles/DeviceTypes/`.
    let modelIdentifier: String
    /// Names this device's baselines apart from the phone's, as in `afternoon.wide.png`. The test
    /// bundle copies every baseline into one folder, where two suites' same-named tests would collide.
    let baselineName: String?

    /// `SnapshotTests`' device.
    static let phone = SnapshotDevice(name: "iPhone 18 Pro", modelIdentifier: "iPhone19,2", baselineName: nil)

    /// `WideSnapshotTests`' device. The narrowest regular width, where the day panel first
    /// shows, and the closest stand-in for an opened foldable iPhone, which has no simulator.
    static let wide = SnapshotDevice(name: "iPad mini (A17 Pro)", modelIdentifier: "iPad16,2", baselineName: "wide")
}

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
    on device: SnapshotDevice = .phone,
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
    guard let scene = UIApplication.shared.connectedScenes.lazy.compactMap({ $0 as? UIWindowScene }).first else {
        Issue.record("Snapshots need the host app's window scene.", sourceLocation: sourceLocation)
        return
    }
    if let mismatch = mismatch(with: device, in: scene) {
        Issue.record(Comment(rawValue: mismatch), sourceLocation: sourceLocation)
        return
    }

    let image = await render(view, on: scene)
    assertSnapshot(
        of: image,
        as: .image(precision: precision, perceptualPrecision: perceptualPrecision),
        named: name ?? device.baselineName,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
}

/// Shows `view` full screen in its own window on `scene` until it settles, and captures it.
@MainActor
private func render<V: View>(_ view: V, on scene: UIWindowScene) async -> UIImage {
    let window = UIWindow(windowScene: scene)
    window.frame = scene.effectiveGeometry.coordinateSpace.bounds
    // Above the host app's own window, which keeps running underneath.
    window.windowLevel = .alert + 1
    // Light, as a new simulator starts, rather than whatever this one was left in. Screens that
    // follow the system scheme, like the details page's glass, otherwise differ between Macs.
    window.overrideUserInterfaceStyle = .light
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
    return await settledImage(of: window)
}

/// Why this run can't take `device`'s snapshots, or nil when it can.
@MainActor
private func mismatch(with device: SnapshotDevice, in scene: UIWindowScene) -> String? {
    let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
    guard model == device.modelIdentifier else {
        return """
            This snapshot is recorded on \(device.name) (\(device.modelIdentifier)), not \(model ?? "an unknown device"). \
            Run it through ./scripts/snapshots.sh.
            """
    }
    // Time labels format with the process locale rather than the SwiftUI environment,
    // so the locale can't be pinned from here; the scripts launch tests with it.
    guard Locale.current.language.languageCode == .english, Locale.current.region == .unitedStates else {
        return "Snapshots are recorded in en_US, not \(Locale.current.identifier). Run them through ./scripts/snapshots.sh."
    }
    // A simulator left rotated, or an iPad app in a window, lays every screen out anew, and a
    // narrow window can even change the size class.
    let bounds = scene.effectiveGeometry.coordinateSpace.bounds
    guard bounds.size == scene.screen.bounds.size, bounds.height > bounds.width else {
        return "Snapshots are recorded full screen in portrait, not in a \(Int(bounds.width))×\(Int(bounds.height)) scene."
    }
    return nil
}

/// Captures `window` until two captures in a row match, so the baseline shows the
/// screen after its first-frame work has landed. A screen that never settles, such
/// as one with a spinner, yields its frame at the timeout.
///
/// The settling captures force a render so each one waits for pending updates, but the
/// image returned is the frame already on screen. A forced render draws the timeline's
/// bottom scroll edge effect in either of two faintly different tints at random, while
/// the screen holds one.
@MainActor
private func settledImage(of window: UIWindow) async -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = snapshotScale
    // The renderer otherwise picks 16-bit Display P3 on this device. SnapshotTesting compares
    // 8-bit pixels, and reports most of a 16-bit image as mismatched even when it's identical.
    format.preferredRange = .standard
    let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
    func capture(afterScreenUpdates: Bool = true) -> UIImage {
        renderer.image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: afterScreenUpdates)
        }
    }

    var previous = capture().pngData()
    // Every graphical calendar after a process's first stops at a taller interim height, and only
    // re-measuring it reaches the height the app shows. A slower Mac can land either, so each
    // screen re-measures once its first capture has laid it out.
    invalidateDatePickerSizes(in: window)
    let deadline = ContinuousClock.now + settleTimeout
    while ContinuousClock.now < deadline {
        try? await Task.sleep(for: settleInterval)
        let data = capture().pngData()
        if data == previous {
            break
        }
        previous = data
    }
    return capture(afterScreenUpdates: false)
}

/// Asks every date picker under `view` to measure itself again.
@MainActor
private func invalidateDatePickerSizes(in view: UIView) {
    if let picker = view as? UIDatePicker {
        picker.invalidateIntrinsicContentSize()
    }
    view.subviews.forEach(invalidateDatePickerSizes)
}
