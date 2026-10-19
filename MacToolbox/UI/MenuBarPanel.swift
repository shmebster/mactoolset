import AppKit

@MainActor
enum MenuBarPanel {
    /// Закрывает окно MenuBarExtra, чтобы оно не мешало выбору области/окна и не попадало в запись.
    static func dismiss() {
        NSApp.keyWindow?.close()
    }
}
