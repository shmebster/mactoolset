import AppKit
import Observation

enum SleepAction: String, CaseIterable, Identifiable {
    case sleep, displayOff, shutdown

    var id: Self { self }

    var title: String {
        switch self {
        case .sleep: "Сон"
        case .displayOff: "Экран"
        case .shutdown: "Выключить"
        }
    }

    var countdownPrefix: String {
        switch self {
        case .sleep: "Сон через"
        case .displayOff: "Экран погаснет через"
        case .shutdown: "Выключение через"
        }
    }

    @MainActor
    func perform() {
        switch self {
        case .sleep:
            Self.pmset("sleepnow")
        case .displayOff:
            Self.pmset("displaysleepnow")
        case .shutdown:
            var error: NSDictionary?
            NSAppleScript(source: #"tell application "System Events" to shut down"#)?
                .executeAndReturnError(&error)
            if let error { NSLog("SleepTimer: shutdown failed: \(error)") }
        }
    }

    private static func pmset(_ command: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = [command]
        do { try process.run() } catch { NSLog("SleepTimer: pmset \(command) failed: \(error)") }
    }
}

@MainActor
@Observable
final class SleepTimer {
    static let shared = SleepTimer()
    static let presets = [5, 10, 15, 30, 45, 60, 90, 120]

    private(set) var isActive = false
    private(set) var activeMinutes: Int?
    private(set) var endDate: Date?
    private(set) var now = Date()

    var lastMinutes: Int {
        didSet { UserDefaults.standard.set(lastMinutes, forKey: Keys.lastMinutes) }
    }

    var action: SleepAction {
        didSet { UserDefaults.standard.set(action.rawValue, forKey: Keys.action) }
    }

    var remaining: TimeInterval? {
        endDate.map { $0.timeIntervalSince(now) }
    }

    /// Вызывается прямо перед выполнением действия.
    @ObservationIgnored var willFire: (@MainActor () -> Void)?
    @ObservationIgnored private let ticker = Ticker()

    private enum Keys {
        static let lastMinutes = "sleepTimer.lastMinutes"
        static let action = "sleepTimer.action"
    }

    init() {
        let defaults = UserDefaults.standard
        lastMinutes = defaults.object(forKey: Keys.lastMinutes) as? Int ?? 30
        action = defaults.string(forKey: Keys.action).flatMap(SleepAction.init(rawValue:)) ?? .sleep
    }

    func toggle() {
        isActive ? stop() : start(minutes: lastMinutes)
    }

    func start(minutes: Int) {
        guard minutes > 0 else { return }
        lastMinutes = minutes
        now = Date()
        isActive = true
        activeMinutes = minutes
        endDate = now.addingTimeInterval(TimeInterval(minutes * 60))
        ticker.start(reason: "Sleep Timer countdown") { [weak self] in self?.tick() }
    }

    func extend(minutes: Int) {
        guard let endDate else { return }
        self.endDate = endDate.addingTimeInterval(TimeInterval(minutes * 60))
    }

    func stop() {
        ticker.stop()
        isActive = false
        activeMinutes = nil
        endDate = nil
    }

    private func tick() {
        now = Date()
        guard let endDate, now >= endDate else { return }
        let action = action
        stop()
        willFire?()
        action.perform()
    }
}
