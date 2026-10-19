import AppKit
import SwiftUI

/// Загружает SVG-иконки из бандла (NSImage умеет рендерить SVG нативно)
/// и отдаёт их как template-изображения, которые красятся foregroundStyle.
@MainActor
enum SVGIcon {
    private static var cache: [String: NSImage] = [:]

    static func image(_ name: String, size: CGFloat) -> NSImage {
        let key = "\(name)@\(size)"
        if let cached = cache[key] { return cached }

        guard let url = Bundle.main.url(forResource: name, withExtension: "svg"),
              let image = NSImage(contentsOf: url) else {
            assertionFailure("Missing SVG icon: \(name)")
            return NSImage(size: NSSize(width: size, height: size))
        }
        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        cache[key] = image
        return image
    }
}

struct SVGImage: View {
    let name: String
    var size: CGFloat = 16

    init(_ name: String, size: CGFloat = 16) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image(nsImage: SVGIcon.image(name, size: size))
            .renderingMode(.template)
            .frame(width: size, height: size)
    }
}
