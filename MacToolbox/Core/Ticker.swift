import Foundation

/// Секундный тикер для обратного отсчёта. Пока работает — держит
/// ProcessInfo-activity, чтобы App Nap не «замораживал» таймеры,
/// но не мешает системе уснуть по простою.
@MainActor
final class Ticker {
    private var task: Task<Void, Never>?
    private var activity: NSObjectProtocol?

    func start(reason: String, _ tick: @escaping @MainActor () -> Void) {
        stop()
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: reason
        )
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                tick()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }
}
