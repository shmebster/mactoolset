import AppKit
@preconcurrency import ScreenCaptureKit

/// Системный пикер окна/приложения (SCContentSharingPicker).
@MainActor
final class WindowPicker: NSObject, SCContentSharingPickerObserver {
    static let shared = WindowPicker()

    private var continuation: CheckedContinuation<UncheckedBox<SCContentFilter>?, Never>?

    func pick() async -> SCContentFilter? {
        let picker = SCContentSharingPicker.shared
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleWindow, .singleApplication]
        if let bundleID = Bundle.main.bundleIdentifier {
            configuration.excludedBundleIDs = [bundleID]
        }
        picker.defaultConfiguration = configuration
        picker.add(self)
        picker.isActive = true

        let result = await withCheckedContinuation { continuation in
            self.continuation = continuation
            NSApp.activate()
            picker.present()
        }
        return result?.value
    }

    private func complete(_ filter: UncheckedBox<SCContentFilter>?) {
        let picker = SCContentSharingPicker.shared
        picker.remove(self)
        picker.isActive = false
        continuation?.resume(returning: filter)
        continuation = nil
    }

    nonisolated func contentSharingPicker(
        _ picker: SCContentSharingPicker,
        didUpdateWith filter: SCContentFilter,
        for stream: SCStream?
    ) {
        let box = UncheckedBox(value: filter)
        Task { @MainActor in self.complete(box) }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in self.complete(nil) }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: Error) {
        Task { @MainActor in self.complete(nil) }
    }
}
