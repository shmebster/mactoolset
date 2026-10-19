import Foundation
import IOKit.pwr_mgt
import Observation

@MainActor
@Observable
final class PreventSleep {
    static let shared = PreventSleep()
    static let presets = [15, 30, 60, 120, 180, 300, 480, 0]

    private(set) var isActive = false
    /// Длительность текущей сессии (0 — бессрочно).
    private(set) var activeMinutes: Int?
    private(set) var endDate: Date?
    /// Остаток в минутах. Меняется раз в минуту, поэтому UI и меню-бар не перерисовываются каждую секунду.
    private(set) var remainingMinutes: Int?

    /// Последняя выбранная длительность — используется по клику на переключатель.
    var lastMinutes: Int {
        didSet { UserDefaults.standard.set(lastMinutes, forKey: Keys.lastMinutes) }
    }

    var keepDisplayOn: Bool {
        didSet {
            UserDefaults.standard.set(keepDisplayOn, forKey: Keys.keepDisplayOn)
            if isActive { createAssertion() }
        }
    }

    @ObservationIgnored private var assertionID: IOPMAssertionID = 0
    @ObservationIgnored private let ticker = Ticker()

    private enum Keys {
        static let lastMinutes = "preventSleep.lastMinutes"
        static let keepDisplayOn = "preventSleep.keepDisplayOn"
    }

    init() {
        let defaults = UserDefaults.standard
        lastMinutes = defaults.object(forKey: Keys.lastMinutes) as? Int ?? 60
        keepDisplayOn = defaults.object(forKey: Keys.keepDisplayOn) as? Bool ?? true
    }

    func toggle() {
        isActive ? stop() : start(minutes: lastMinutes)
    }

    func start(minutes: Int) {
        lastMinutes = minutes
        createAssertion()
        isActive = true
        activeMinutes = minutes
        endDate = minutes > 0 ? Date().addingTimeInterval(TimeInterval(minutes * 60)) : nil
        updateRemaining()

        if endDate != nil {
            ticker.start(reason: "Prevent Sleep countdown") { [weak self] in self?.tick() }
        } else {
            ticker.stop()
        }
    }

    func stop() {
        guard isActive else { return }
        ticker.stop()
        releaseAssertion()
        isActive = false
        activeMinutes = nil
        endDate = nil
        remainingMinutes = nil
    }

    /// Проверка каждую секунду (точность срабатывания), но публикуем только смену минуты.
    private func tick() {
        if let endDate, Date() >= endDate {
            stop()
        } else {
            updateRemaining()
        }
    }

    private func updateRemaining() {
        let minutes = endDate.map(DurationFormat.minutesLeft(until:))
        if minutes != remainingMinutes { remainingMinutes = minutes }
    }

    private func createAssertion() {
        releaseAssertion()
        let type = keepDisplayOn
            ? kIOPMAssertionTypePreventUserIdleDisplaySleep
            : kIOPMAssertionTypePreventUserIdleSystemSleep
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Mac Toolbox: Не засыпать" as CFString,
            &id
        )
        if result == kIOReturnSuccess {
            assertionID = id
        } else {
            NSLog("PreventSleep: IOPMAssertionCreateWithName failed: \(result)")
        }
    }

    private func releaseAssertion() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }
}
