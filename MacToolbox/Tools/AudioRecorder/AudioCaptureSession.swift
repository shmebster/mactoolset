import AVFoundation
@preconcurrency import ScreenCaptureKit

/// Захват системного звука и/или микрофона через ScreenCaptureKit.
/// Каждый источник пишется в свой временный .caf (формат берётся из первого буфера),
/// а `AudioMixer` потом сводит их в один .m4a.
final class AudioCaptureSession: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    struct Track: Sendable {
        let url: URL
        let start: CMTime
    }

    private var stream: SCStream!
    private let queue = DispatchQueue(label: "MacToolbox.AudioCapture")
    private let onStop: @Sendable (Error) -> Void

    // Доступ только из `queue`.
    private var files: [SCStreamOutputType: (file: AVAudioFile, track: Track)] = [:]

    init(
        display: SCDisplay,
        systemAudio: Bool,
        microphone: Bool,
        onStop: @escaping @Sendable (Error) -> Void
    ) throws {
        self.onStop = onStop
        super.init()

        let config = SCStreamConfiguration()
        // Видео не нужно, но SCStream без него не работает — берём минимум.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.capturesAudio = systemAudio
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        config.captureMicrophone = microphone

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        if systemAudio { try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue) }
        if microphone { try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue) }
    }

    func start() async throws {
        try await stream.startCapture()
    }

    /// Останавливает захват и возвращает записанные дорожки (файлы закрыты).
    func stop() async -> [Track] {
        try? await stream.stopCapture()
        return queue.sync {
            let tracks = files.values.map(\.track)
            files.removeAll()  // AVAudioFile закрывается при деинициализации
            return tracks
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio || type == .microphone,
              sampleBuffer.isValid,
              let buffer = Self.pcmBuffer(from: sampleBuffer) else { return }

        do {
            if files[type] == nil {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("MacToolbox-\(UUID().uuidString).caf")
                // CAF всегда interleaved — флаг из формата буфера только сбивает AVAudioFile.
                var settings = buffer.format.settings
                settings.removeValue(forKey: AVLinearPCMIsNonInterleaved)
                let file = try AVAudioFile(
                    forWriting: url,
                    settings: settings,
                    commonFormat: buffer.format.commonFormat,
                    interleaved: buffer.format.isInterleaved
                )
                files[type] = (file, Track(url: url, start: sampleBuffer.presentationTimeStamp))
            }
            try files[type]?.file.write(from: buffer)
        } catch {
            NSLog("AudioCapture: write failed: \(error)")
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStop(error)
    }

    private static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let description = sampleBuffer.formatDescription else { return nil }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        let frames = AVAudioFrameCount(sampleBuffer.numSamples)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList
        )
        return status == noErr ? buffer : nil
    }
}

enum AudioMixer {
    /// Сводит дорожки (с учётом их времени начала) в один AAC .m4a и удаляет временные файлы.
    static func mix(_ tracks: [AudioCaptureSession.Track], to output: URL) async throws {
        defer { tracks.forEach { try? FileManager.default.removeItem(at: $0.url) } }
        guard let origin = tracks.map(\.start).min() else { throw CaptureError.nothingRecorded }

        let composition = AVMutableComposition()
        for track in tracks {
            let asset = AVURLAsset(url: track.url)
            guard let source = try await asset.loadTracks(withMediaType: .audio).first,
                  let target = composition.addMutableTrack(
                      withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid
                  ) else { continue }
            let duration = try await asset.load(.duration)
            try target.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: source,
                at: CMTimeSubtract(track.start, origin)
            )
        }

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
        else { throw CaptureError.nothingRecorded }
        try await export.export(to: output, as: .m4a)
    }
}
