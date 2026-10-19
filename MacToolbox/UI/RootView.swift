import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                SVGImage("toolbox", size: 16)
                Text("Mac Toolbox")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                SettingsMenu()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            VStack(spacing: 8) {
                PreventSleepView()
                SleepTimerView()
                ScreenRecorderView()
                AudioRecorderView()
            }
            .padding(10)
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SettingsMenu: View {
    @AppStorage("ui.showCountdown") private var showCountdown = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Menu {
            Toggle("Запускать при входе", isOn: $launchAtLogin)
            Toggle("Обратный отсчёт в меню-баре", isOn: $showCountdown)
            Button("Открыть папку видеозаписей") { NSWorkspace.shared.open(Recordings.videoFolder) }
            Button("Открыть папку аудиозаписей") { NSWorkspace.shared.open(Recordings.audioFolder) }
            Divider()
            Button("Выйти из Mac Toolbox") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            SVGImage("settings", size: 15)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onChange(of: launchAtLogin) { _, enabled in
            LaunchAtLogin.set(enabled)
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}
