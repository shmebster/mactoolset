import Foundation

/// Длительности хранятся в минутах; 0 означает «бессрочно».
enum DurationFormat {
    static func short(_ minutes: Int) -> String {
        if minutes == 0 { return "бессрочно" }
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) мин"
        case (_, 0): return "\(h) ч"
        default: return "\(h) ч \(m) мин"
        }
    }

    /// Компактная подпись для чипа в сетке пресетов.
    static func chip(_ minutes: Int) -> String {
        if minutes == 0 { return "∞" }
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m == 30 { return "\(h),5 ч" }
        return short(minutes)
    }

    /// Компактный остаток без секунд: «45м», «1ч», «1ч 5м».
    static func compact(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m)м"
        case (_, 0): return "\(h)ч"
        default: return "\(h)ч \(m)м"
        }
    }

    /// Оставшиеся минуты с округлением вверх: сразу после старта 30-минутного таймера — «30м», в последнюю минуту — «1м».
    static func minutesLeft(until date: Date) -> Int {
        max(1, Int((date.timeIntervalSinceNow / 60).rounded(.up)))
    }

    static func countdown(_ seconds: TimeInterval) -> String {
        let t = max(0, Int(seconds.rounded(.up)))
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
