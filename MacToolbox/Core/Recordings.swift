import AppKit

/// Куда и под какими именами сохраняются записи.
enum Recordings {
    static var videoFolder: URL { folder(in: .moviesDirectory) }
    static var audioFolder: URL { folder(in: .musicDirectory) }

    static func newVideoURL() -> URL {
        videoFolder.appendingPathComponent("Запись экрана \(timestamp()).mov")
    }

    static func newAudioURL() -> URL {
        audioFolder.appendingPathComponent("Запись звука \(timestamp()).m4a")
    }

    @MainActor
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private static func folder(in directory: FileManager.SearchPathDirectory) -> URL {
        let base = FileManager.default.urls(for: directory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Mac Toolbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'в' HH.mm.ss"
        return formatter.string(from: Date())
    }
}
