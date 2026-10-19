import AppKit
import Observation
@preconcurrency import ScreenCaptureKit

enum CaptureMode: String, CaseIterable, Identifiable {
    case display, window, area

    var id: Self { self }

    /// Режимы карточки «Запись экрана»; окно — отдельный инструмент.
    static let screenModes: [CaptureMode] = [.display, .area]

    var title: String {
        switch self {
        case .display: "Весь экран"
        case .window: "Окно"
        case .area: "Область"
        }
    }
}

@MainActor
@Observable
final class ScreenRecorder {
    /// Два инструмента на одном движке: «Запись экрана» (весь экран / область) и «Запись окна».
    enum Kind { case screen, window }

    static let screen = ScreenRecorder(kind: .screen)
    static let window = ScreenRecorder(kind: .window)
    static var all: [ScreenRecorder] { [screen, window] }

    let kind: Kind

    enum Phase: Equatable { case idle, preparing, recording, saving }

    private(set) var phase = Phase.idle
    private(set) var startDate: Date?
    private(set) var now = Date()
    private(set) var lastRecording: URL?
    private(set) var errorMessage: String?

    /// Последний режим — используется по клику на переключатель.
    var mode: CaptureMode { didSet { defaults.set(mode.rawValue, forKey: key("mode")) } }
    var systemAudio: Bool { didSet { defaults.set(systemAudio, forKey: key("systemAudio")) } }
    var microphone: Bool { didSet { defaults.set(microphone, forKey: key("microphone")) } }
    var showCursor: Bool { didSet { defaults.set(showCursor, forKey: key("showCursor")) } }
    var showClicks: Bool { didSet { defaults.set(showClicks, forKey: key("showClicks")) } }

    var isActive: Bool { phase != .idle }

    /// Запись идёт в другом инструменте — одновременно пишем только что-то одно.
    var isBlocked: Bool {
        Self.all.contains { $0 !== self && $0.isActive }
    }
    var elapsed: TimeInterval? { startDate.map { now.timeIntervalSince($0) } }

    @ObservationIgnored private var session: ScreenCaptureSession?
    @ObservationIgnored private let ticker = Ticker()
    @ObservationIgnored private let defaults = UserDefaults.standard

    private var defaultsPrefix: String { Self.defaultsPrefix(kind) }

    private static func defaultsPrefix(_ kind: Kind) -> String {
        kind == .screen ? "screenRecorder" : "windowRecorder"
    }

    private func key(_ name: String) -> String { "\(defaultsPrefix).\(name)" }

    init(kind: Kind) {
        self.kind = kind
        let d = UserDefaults.standard
        let prefix = Self.defaultsPrefix(kind)
        switch kind {
        case .screen:
            let stored = d.string(forKey: "\(prefix).mode").flatMap(CaptureMode.init(rawValue:))
            mode = stored.flatMap { CaptureMode.screenModes.contains($0) ? $0 : nil } ?? .display
        case .window:
            mode = .window
        }
        systemAudio = d.object(forKey: "\(prefix).systemAudio") as? Bool ?? true
        microphone = d.object(forKey: "\(prefix).microphone") as? Bool ?? false
        showCursor = d.object(forKey: "\(prefix).showCursor") as? Bool ?? (kind == .screen)
        showClicks = d.object(forKey: "\(prefix).showClicks") as? Bool ?? false
    }

    func toggle() {
        phase == .idle ? start(mode: mode) : stop()
    }

    func start(mode: CaptureMode) {
        guard phase == .idle, !isBlocked else { return }
        self.mode = mode
        errorMessage = nil
        phase = .preparing
        MenuBarPanel.dismiss()
        Task { await begin() }
    }

    func stop() {
        guard phase == .recording, let session else { return }
        phase = .saving
        Task { await session.stop() }
    }

    func revealLastRecording() {
        if let lastRecording { Recordings.reveal(lastRecording) }
    }

    // MARK: - Private

    private struct Target {
        let filter: SCContentFilter
        let size: CGSize          // в пикселях
        var sourceRect: CGRect?   // в точках дисплея
    }

    private func begin() async {
        do {
            if microphone, !(await Permissions.requestMicrophone()) {
                throw CaptureError.microphoneDenied
            }
            guard let target = try await makeTarget() else {
                phase = .idle  // пользователь отменил выбор
                return
            }

            let url = Recordings.newVideoURL(prefix: kind == .window ? "Запись окна" : "Запись экрана")
            let session = try ScreenCaptureSession(
                filter: target.filter,
                configuration: configuration(for: target),
                url: url,
                onFinish: { [weak self] error in
                    Task { @MainActor in self?.didFinish(url: url, error: error) }
                }
            )
            try await session.start()

            self.session = session
            now = Date()
            startDate = now
            phase = .recording
            ticker.start(reason: "Screen recording") { [weak self] in self?.now = Date() }
        } catch {
            fail(error)
        }
    }

    private func makeTarget() async throws -> Target? {
        switch mode {
        case .display:
            let (display, filter, scale) = try await displayFilter(for: screenUnderMouse())
            return Target(
                filter: filter,
                size: CGSize(width: CGFloat(display.width) * scale, height: CGFloat(display.height) * scale)
            )

        case .area:
            guard let selection = await AreaSelector.select() else { return nil }
            let (_, filter, scale) = try await displayFilter(for: selection.screen)
            return Target(
                filter: filter,
                size: CGSize(width: selection.rect.width * scale, height: selection.rect.height * scale),
                sourceRect: selection.rect
            )

        case .window:
            guard let filter = await WindowPicker.shared.pick() else { return nil }
            let scale = CGFloat(filter.pointPixelScale)
            return Target(
                filter: filter,
                size: CGSize(width: filter.contentRect.width * scale, height: filter.contentRect.height * scale)
            )
        }
    }

    /// Фильтр «весь дисплей без окон самого Mac Toolbox».
    private func displayFilter(for screen: NSScreen) async throws -> (SCDisplay, SCContentFilter, CGFloat) {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let displayID = screen.displayID
        guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first
        else { throw CaptureError.noDisplay }
        let ownApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        return (display, filter, screen.backingScaleFactor)
    }

    private func configuration(for target: Target) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        // Кодеку нужны чётные размеры.
        config.width = max(Int(target.size.width.rounded()) & ~1, 2)
        config.height = max(Int(target.size.height.rounded()) & ~1, 2)
        if let sourceRect = target.sourceRect { config.sourceRect = sourceRect }
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 6
        config.showsCursor = showCursor
        config.showMouseClicks = showClicks
        config.capturesAudio = systemAudio
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        config.captureMicrophone = microphone
        return config
    }

    private func screenUnderMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func didFinish(url: URL, error: Error?) {
        ticker.stop()
        session = nil
        startDate = nil
        phase = .idle
        if FileManager.default.fileExists(atPath: url.path) {
            lastRecording = url
            Recordings.reveal(url)
        } else if let error {
            fail(error)
        }
    }

    private func fail(_ error: Error) {
        NSLog("ScreenRecorder: \(error)")
        ticker.stop()
        session = nil
        startDate = nil
        phase = .idle
        errorMessage = error.localizedDescription
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
