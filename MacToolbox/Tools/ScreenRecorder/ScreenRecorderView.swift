import SwiftUI

/// «Запись экрана»: весь экран или выделенная область.
struct ScreenRecorderView: View {
    private let model = ScreenRecorder.screen
    @AppStorage("ui.expanded.screenRecorder") private var isExpanded = false

    private let tint = Color.red

    var body: some View {
        ToolCard(
            icon: "screen-record",
            tint: tint,
            title: "Запись экрана",
            status: RecorderStatus.text(for: model) {
                "По умолчанию: \(model.mode.title.lowercased())"
            },
            isActive: model.isActive,
            isToggleEnabled: !model.isBlocked,
            onToggle: { model.toggle() },
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(CaptureMode.screenModes) { mode in
                        Button(mode.title) { model.start(mode: mode) }
                            .buttonStyle(ChipStyle(
                                tint: tint,
                                isActive: model.isActive && model.mode == mode,
                                isDefault: model.mode == mode
                            ))
                            .disabled(model.isActive || model.isBlocked)
                    }
                }
                RecorderOptions(model: model)
            }
            .font(.system(size: 12))
        }
    }
}

/// «Запись окна»: окно или приложение через системный пикер.
struct WindowRecorderView: View {
    private let model = ScreenRecorder.window
    @AppStorage("ui.expanded.windowRecorder") private var isExpanded = false

    private let tint = Color.blue

    var body: some View {
        ToolCard(
            icon: "window-record",
            tint: tint,
            title: "Запись окна",
            status: RecorderStatus.text(for: model) { "Выбор окна при запуске" },
            isActive: model.isActive,
            isToggleEnabled: !model.isBlocked,
            onToggle: { model.toggle() },
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Button("Выбрать окно…") { model.start(mode: .window) }
                    .buttonStyle(ChipStyle(tint: tint, isActive: model.isActive, isDefault: true))
                    .disabled(model.isActive || model.isBlocked)
                RecorderOptions(model: model)
            }
            .font(.system(size: 12))
        }
    }
}

/// Общие настройки записи: звук, курсор, клики + ошибка и последняя запись.
private struct RecorderOptions: View {
    @Bindable var model: ScreenRecorder

    var body: some View {
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
}

private enum RecorderStatus {
    @MainActor
    static func text(for model: ScreenRecorder, idle: () -> String) -> String {
        switch model.phase {
        case .idle:
            if model.errorMessage != nil { return "Ошибка — подробности ниже" }
            if model.isBlocked { return "Идёт другая запись" }
            return idle()
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
