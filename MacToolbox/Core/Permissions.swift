import AVFoundation
import AppKit

enum Permissions {
    static func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
        default: false
        }
    }

    @MainActor
    static func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    @MainActor
    static func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    @MainActor
    private static func open(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}

enum CaptureError: LocalizedError {
    case microphoneDenied
    case noDisplay
    case nothingRecorded

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "Нет доступа к микрофону"
        case .noDisplay: "Не найден дисплей для записи"
        case .nothingRecorded: "Звук не был записан"
        }
    }
}

/// Переносит не-Sendable значения фреймворков (SCContentFilter и т.п.) через границу акторов.
struct UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
}
