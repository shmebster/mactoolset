import SwiftUI

/// Иконка в меню-баре: отражает активный инструмент и (опционально) показывает отсчёт.
/// Таймер сна приоритетнее — он ведёт к действию.
struct MenuBarLabel: View {
    private let preventSleep = PreventSleep.shared
    private let sleepTimer = SleepTimer.shared
    @AppStorage("ui.showCountdown") private var showCountdown = true

    var body: some View {
        let (icon, remaining) = state
        HStack(spacing: 4) {
            Image(nsImage: SVGIcon.image(icon, size: 18))
            if showCountdown, let remaining {
                Text(DurationFormat.countdown(remaining))
                    .monospacedDigit()
            }
        }
    }

    private var state: (String, TimeInterval?) {
        if sleepTimer.isActive {
            return ("sleep-timer", sleepTimer.remaining)
        }
        if preventSleep.isActive {
            return ("prevent-sleep", preventSleep.remaining)
        }
        return ("toolbox", nil)
    }
}
