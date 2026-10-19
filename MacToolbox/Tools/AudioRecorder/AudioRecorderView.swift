import SwiftUI

struct AudioRecorderView: View {
    @Bindable private var model = AudioRecorder.shared
    @AppStorage("ui.expanded.audioRecorder") private var isExpanded = false

    private let tint = Color.pink

    var body: some View {
        ToolCard(
            icon: "audio-record",
            tint: tint,
            title: "Запись звука",
            status: status,
            isActive: model.isActive,
            onToggle: { model.toggle() },
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ChipPicker(options: AudioSource.allCases, title: \.title, selection: $model.source, tint: tint)
                    .disabled(model.isActive)

                RecordingFooter(
                    errorMessage: model.errorMessage,
                    lastRecording: model.lastRecording,
                    openSettings: {
                        model.source.includesMicrophone
                            ? Permissions.openMicrophoneSettings()
                            : Permissions.openScreenRecordingSettings()
                    },
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
            return "Источник: \(model.source.title.lowercased())"
        case .preparing:
            return "Подготовка…"
        case .recording:
            return "Запись · \(DurationFormat.countdown(model.elapsed ?? 0))"
        case .saving:
            return "Сохранение…"
        }
    }
}
