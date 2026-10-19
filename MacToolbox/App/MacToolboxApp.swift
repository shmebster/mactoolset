import SwiftUI

@main
struct MacToolboxApp: App {
    init() {
        // Явный сон по таймеру не должен «просыпаться» обратно в режим «Не засыпать».
        SleepTimer.shared.willFire = { PreventSleep.shared.stop() }
        #if DEBUG
        DispatchQueue.main.async { PreviewWindow.showIfRequested() }
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            RootView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}
