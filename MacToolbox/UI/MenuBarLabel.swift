import SwiftUI

/// Иконка в меню-баре: отражает активный инструмент и (опционально) показывает отсчёт.
/// Приоритет: идущая запись, затем таймер сна (ведёт к действию), затем «Не засыпать».
struct MenuBarLabel: View {
    private let preventSleep = PreventSleep.shared
    private let sleepTimer = SleepTimer.shared
    private let screenRecorder = ScreenRecorder.shared
    private let audioRecorder = AudioRecorder.shared
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
        if screenRecorder.phase == .recording {
            return ("record", screenRecorder.elapsed)
        }
        if audioRecorder.phase == .recording {
            return ("record", audioRecorder.elapsed)
        }
        if sleepTimer.isActive {
            return ("sleep-timer", sleepTimer.remaining)
        }
        if preventSleep.isActive {
            return ("prevent-sleep", preventSleep.remaining)
        }
        return ("toolbox", nil)
    }
}
