#if DEBUG
import AppKit
import SwiftUI

/// `MacToolbox --preview-window` открывает панель в обычном окне —
/// удобно для скриншотов в документацию и отладки вёрстки без клика по меню-бару.
@MainActor
enum PreviewWindow {
    private static var window: NSWindow?

    static func showIfRequested() {
        guard CommandLine.arguments.contains("--preview-window") else { return }
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        [.closeButton, .miniaturizeButton, .zoomButton].forEach { window.standardWindowButton($0)?.isHidden = true }
        window.contentView = NSHostingView(rootView: RootView().background(.regularMaterial))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        Self.window = window
    }
}
#endif
