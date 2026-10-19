import Observation
@preconcurrency import ScreenCaptureKit

enum AudioSource: String, CaseIterable, Identifiable {
    case system, microphone, both

    var id: Self { self }

    var title: String {
        switch self {
        case .system: "Система"
        case .microphone: "Микрофон"
        case .both: "Оба"
        }
    }

    var includesSystem: Bool { self != .microphone }
    var includesMicrophone: Bool { self != .system }
}

@MainActor
@Observable
final class AudioRecorder {
    static let shared = AudioRecorder()

    enum Phase: Equatable { case idle, preparing, recording, saving }

    private(set) var phase = Phase.idle
    private(set) var startDate: Date?
    private(set) var now = Date()
    private(set) var lastRecording: URL?
    private(set) var errorMessage: String?

    var source: AudioSource {
        didSet { UserDefaults.standard.set(source.rawValue, forKey: Keys.source) }
    }

    var isActive: Bool { phase != .idle }
    var elapsed: TimeInterval? { startDate.map { now.timeIntervalSince($0) } }

    @ObservationIgnored private var session: AudioCaptureSession?
    @ObservationIgnored private let ticker = Ticker()

    private enum Keys {
        static let source = "audioRecorder.source"
    }

    init() {
        source = UserDefaults.standard.string(forKey: Keys.source).flatMap(AudioSource.init(rawValue:)) ?? .system
    }

    func toggle() {
        phase == .idle ? start() : stop()
    }

    func start() {
        guard phase == .idle else { return }
        errorMessage = nil
        phase = .preparing
        Task { await begin() }
    }

    func stop() {
        guard phase == .recording, let session else { return }
        phase = .saving
        ticker.stop()
        Task {
            let tracks = await session.stop()
            let url = Recordings.newAudioURL()
            do {
                try await AudioMixer.mix(tracks, to: url)
                lastRecording = url
                Recordings.reveal(url)
                reset()
            } catch {
                fail(error)
            }
        }
    }

    func revealLastRecording() {
        if let lastRecording { Recordings.reveal(lastRecording) }
    }

    private func begin() async {
        do {
            if source.includesMicrophone, !(await Permissions.requestMicrophone()) {
                throw CaptureError.microphoneDenied
            }
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { throw CaptureError.noDisplay }

            let session = try AudioCaptureSession(
                display: display,
                systemAudio: source.includesSystem,
                microphone: source.includesMicrophone,
                onStop: { [weak self] error in
                    // Остановка извне (например, через системный индикатор) — сохраняем что успели.
                    Task { @MainActor in
                        NSLog("AudioRecorder: stream stopped: \(error)")
                        self?.stop()
                    }
                }
            )
            try await session.start()

            self.session = session
            now = Date()
            startDate = now
            phase = .recording
            ticker.start(reason: "Audio recording") { [weak self] in self?.now = Date() }
        } catch {
            fail(error)
        }
    }

    private func reset() {
        ticker.stop()
        session = nil
        startDate = nil
        phase = .idle
    }

    private func fail(_ error: Error) {
        NSLog("AudioRecorder: \(error)")
        reset()
        errorMessage = error.localizedDescription
    }
}
