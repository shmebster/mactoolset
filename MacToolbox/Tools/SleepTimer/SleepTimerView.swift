import SwiftUI

struct SleepTimerView: View {
    @Bindable private var model = SleepTimer.shared
    @AppStorage("ui.expanded.sleepTimer") private var isExpanded = false

    private let tint = Color.indigo

    var body: some View {
        ToolCard(
            icon: "sleep-timer",
            tint: tint,
            title: "Таймер сна",
            status: status,
            isActive: model.isActive,
            onToggle: { model.toggle() },
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ChipPicker(options: SleepAction.allCases, title: \.title, selection: $model.action, tint: tint)

                DurationPicker(
                    presets: SleepTimer.presets,
                    tint: tint,
                    activeMinutes: model.activeMinutes,
                    defaultMinutes: model.lastMinutes,
                    onPick: { model.start(minutes: $0) }
                )

                if model.isActive {
                    HStack(spacing: 6) {
                        ForEach([5, 15, 30], id: \.self) { minutes in
                            Button("+\(minutes) мин") { model.extend(minutes: minutes) }
                                .buttonStyle(ChipStyle(tint: tint, isActive: false, isDefault: false))
                        }
                    }
                }
            }
        }
    }

    private var status: String {
        guard model.isActive, let minutes = model.remainingMinutes else {
            return "По умолчанию: \(DurationFormat.short(model.lastMinutes))"
        }
        return "\(model.action.countdownPrefix) \(DurationFormat.compact(minutes: minutes))"
    }
}
