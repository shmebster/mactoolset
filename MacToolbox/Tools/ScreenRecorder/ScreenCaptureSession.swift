import AVFoundation
import os
@preconcurrency import ScreenCaptureKit

/// Обёртка над SCStream + SCRecordingOutput: пишет видео (и звук) прямо в .mov.
final class ScreenCaptureSession: NSObject, SCStreamDelegate, SCStreamOutput, SCRecordingOutputDelegate,
    @unchecked Sendable {
    let url: URL

    private var stream: SCStream!
    private let queue = DispatchQueue(label: "MacToolbox.ScreenCapture")
    private let onFinish: @Sendable (Error?) -> Void
    private let finished = OSAllocatedUnfairLock(initialState: false)

    init(
        filter: SCContentFilter,
        configuration: SCStreamConfiguration,
        url: URL,
        onFinish: @escaping @Sendable (Error?) -> Void
    ) throws {
        self.url = url
        self.onFinish = onFinish
        super.init()

        let outputConfiguration = SCRecordingOutputConfiguration()
        outputConfiguration.outputURL = url
        outputConfiguration.outputFileType = .mov
        outputConfiguration.videoCodecType = .hevc

        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        // Пустой обработчик кадров — иначе SCStream засоряет лог сообщениями о потерянных кадрах.
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try stream.addRecordingOutput(SCRecordingOutput(configuration: outputConfiguration, delegate: self))
    }

    func start() async throws {
        try await stream.startCapture()
    }

    func stop() async {
        do {
            try await stream.stopCapture()
        } catch {
            finish(error)
        }
    }

    private func finish(_ error: Error?) {
        let first = finished.withLock { done in
            defer { done = true }
            return !done
        }
        if first { onFinish(error) }
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {}

    // MARK: SCStreamDelegate

    /// Сюда же приходит остановка через системный индикатор записи в меню-баре.
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        finish(error)
    }

    // MARK: SCRecordingOutputDelegate

    func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        finish(nil)
    }

    func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        finish(error)
    }
}
