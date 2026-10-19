import SwiftUI

struct ScreenRecorderView: View {
    @Bindable private var model = ScreenRecorder.shared
    @AppStorage("ui.expanded.screenRecorder") private var isExpanded = false

    private let tint = Color.red

    var body: some View {
        ToolCard(
            icon: "screen-record",
            tint: tint,
            title: "Запись экрана",
            status: status,
            isActive: model.isActive,
            onToggle: { model.toggle() },
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(CaptureMode.allCases) { mode in
                        Button(mode.title) { model.start(mode: mode) }
                            .buttonStyle(ChipStyle(
                                tint: tint,
                                isActive: model.isActive && model.mode == mode,
                                isDefault: model.mode == mode
                            ))
                            .disabled(model.isActive)
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Toggle("Системный звук", isOn: $model.systemAudio)
                        Toggle("Микрофон", isOn: $model.microphone)
                    }
                    GridRow {
                        Toggle("Курсор", isOn: $model.showCursor)
                        Toggle("Подсветка кликов", isOn: $model.showClicks)
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(model.isActive)

                RecordingFooter(
                    errorMessage: model.errorMessage,
                    lastRecording: model.lastRecording,
                    openSettings: Permissions.openScreenRecordingSettings,
                    reveal: model.revealLastRecording
                )
            }
            .font(.system(size: 12))
        }
    }

    private var status: String {
        switch model.phase {
        case .idle:
            if model.errorMessage != nil { return "Ошибка — подробности ниже" }
            return "По умолчанию: \(model.mode.title.lowercased())"
        case .preparing:
            return "Подготовка…"
        case .recording:
            return "Запись · \(DurationFormat.countdown(model.elapsed ?? 0))"
        case .saving:
            return "Сохранение…"
        }
    }
}

/// Ошибка с кнопкой «Настройки» и ссылка на последнюю запись.
struct RecordingFooter: View {
    let errorMessage: String?
    let lastRecording: URL?
    let openSettings: @MainActor () -> Void
    let reveal: @MainActor () -> Void

    var body: some View {
        if let errorMessage {
            HStack(alignment: .firstTextBaseline) {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Настройки…") { openSettings() }
                    .controlSize(.small)
            }
        }
        if let lastRecording {
            Button {
                reveal()
            } label: {
                Text("Последняя: \(lastRecording.lastPathComponent)")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .buttonStyle(.link)
        }
    }
}
