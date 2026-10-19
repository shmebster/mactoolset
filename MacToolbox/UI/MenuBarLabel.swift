import SwiftUI

/// Иконка в меню-баре: отражает активный инструмент и (опционально) показывает отсчёт.
/// Приоритет: идущая запись, затем таймер сна (ведёт к действию), затем «Не засыпать».
struct MenuBarLabel: View {
    private let preventSleep = PreventSleep.shared
    private let sleepTimer = SleepTimer.shared
    private let audioRecorder = AudioRecorder.shared
    @AppStorage("ui.showCountdown") private var showCountdown = true

    var body: some View {
        let (icon, text) = state
        HStack(spacing: 4) {
            Image(nsImage: SVGIcon.image(icon, size: 18))
            if showCountdown, let text {
                Text(text)
                    .monospacedDigit()
            }
        }
    }

    /// Записи показывают секунды, таймеры — только минуты (обновляются раз в минуту).
    private var state: (String, String?) {
        if let recorder = ScreenRecorder.all.first(where: { $0.phase == .recording }) {
            return ("record", recorder.elapsed.map(DurationFormat.countdown))
        }
        if audioRecorder.phase == .recording {
            return ("record", audioRecorder.elapsed.map(DurationFormat.countdown))
        }
        if sleepTimer.isActive {
            return ("sleep-timer", sleepTimer.remainingMinutes.map { DurationFormat.compact(minutes: $0) })
        }
        if preventSleep.isActive {
            return ("prevent-sleep", preventSleep.remainingMinutes.map { DurationFormat.compact(minutes: $0) })
        }
        return ("toolbox", nil)
    }
}
