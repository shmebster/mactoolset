import SwiftUI

struct PreventSleepView: View {
    @Bindable private var model = PreventSleep.shared
    @AppStorage("ui.expanded.preventSleep") private var isExpanded = false

    private let tint = Color.orange

    var body: some View {
        ToolCard(
            icon: "prevent-sleep",
            tint: tint,
            title: "Не засыпать",
            status: status,
            isActive: model.isActive,
            onToggle: { model.toggle() },
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 10) {
                DurationPicker(
                    presets: PreventSleep.presets,
                    tint: tint,
                    activeMinutes: model.activeMinutes,
                    defaultMinutes: model.lastMinutes,
                    onPick: { model.start(minutes: $0) }
                )
                Toggle("Не гасить экран", isOn: $model.keepDisplayOn)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
            }
        }
    }

    private var status: String {
        guard model.isActive else {
            return "По умолчанию: \(DurationFormat.short(model.lastMinutes))"
        }
        if let minutes = model.remainingMinutes {
            return "Активно · ещё \(DurationFormat.compact(minutes: minutes))"
        }
        return "Активно · бессрочно"
    }
}
