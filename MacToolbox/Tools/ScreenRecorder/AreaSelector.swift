import AppKit
import SwiftUI

/// Полноэкранный оверлей на экране под курсором: протяните мышью, чтобы выбрать область.
/// Возвращает экран и прямоугольник в его координатах (точки, начало — левый верхний угол).
@MainActor
final class AreaSelector {
    // Создаётся и используется только на главном акторе.
    struct Selection: @unchecked Sendable {
        let screen: NSScreen
        let rect: CGRect
    }

    private static var window: OverlayWindow?

    static func select() async -> Selection? {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return nil }

        return await withCheckedContinuation { continuation in
            let window = OverlayWindow(screen: screen)
            let finish: (CGRect?) -> Void = { rect in
                NSCursor.pop()
                Self.window?.orderOut(nil)
                Self.window = nil
                continuation.resume(returning: rect.map { Selection(screen: screen, rect: $0) })
            }
            window.onCancel = { finish(nil) }
            window.contentView = NSHostingView(rootView: SelectionOverlay(onComplete: finish))
            Self.window = window

            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            NSCursor.crosshair.push()
        }
    }
}

private final class OverlayWindow: NSWindow {
    var onCancel: (() -> Void)?

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } else { super.keyDown(with: event) }  // Esc
    }

    override func rightMouseDown(with event: NSEvent) {
        onCancel?()
    }
}

private struct SelectionOverlay: View {
    let onComplete: (CGRect?) -> Void

    @State private var start: CGPoint?
    @State private var current: CGPoint?

    private var selection: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(
            x: min(start.x, current.x), y: min(start.y, current.y),
            width: abs(current.x - start.x), height: abs(current.y - start.y)
        ).integral
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    if let selection { path.addRect(selection) }
                }
                .fill(Color.black.opacity(0.35), style: FillStyle(eoFill: true))

                if let selection {
                    Rectangle()
                        .strokeBorder(Color.white, lineWidth: 1)
                        .frame(width: selection.width, height: selection.height)
                        .offset(x: selection.minX, y: selection.minY)
                    Text("\(Int(selection.width)) × \(Int(selection.height))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.6)))
                        .offset(x: selection.minX, y: max(selection.minY - 24, 4))
                } else {
                    Text("Выделите область для записи · Esc — отмена")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(.black.opacity(0.6)))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        start = value.startLocation
                        current = value.location
                    }
                    .onEnded { _ in
                        if let selection, selection.width >= 16, selection.height >= 16 {
                            onComplete(selection)
                        } else {
                            start = nil
                            current = nil
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }
}
