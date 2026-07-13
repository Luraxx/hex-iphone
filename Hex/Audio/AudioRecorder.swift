import AVFoundation
import Foundation

enum RecorderError: LocalizedError {
    case alreadyCapturing
    case noInputAvailable
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .alreadyCapturing: "Es läuft bereits eine Aufnahme."
        case .noInputAvailable: "Kein Mikrofon-Eingang verfügbar."
        case .converterUnavailable: "Audio-Konvertierung nicht möglich."
        }
    }
}

/// Records from the microphone and writes a 16 kHz mono Float32 WAV file directly —
/// the input format Parakeet expects. The engine deliberately keeps running after
/// `finishCapture()` so the audio background mode keeps the app alive during
/// transcription; only `shutdown()` stops everything.
final class AudioRecorder {
    struct CaptureResult {
        let url: URL
        let duration: TimeInterval
    }

    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var converter: AVAudioConverter?
    private var framesWritten: AVAudioFramePosition = 0
    private(set) var isCapturing = false

    /// Level 0...1, reported from the audio tap thread.
    var onLevel: ((Float) -> Void)?

    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: [])
    }

    func startCapture(to url: URL) throws {
        guard !isCapturing else { throw RecorderError.alreadyCapturing }
        try configureSession()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.noInputAvailable
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw RecorderError.converterUnavailable
        }
        self.converter = converter

        try? FileManager.default.removeItem(at: url)
        file = try AVAudioFile(
            forWriting: url,
            settings: targetFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        framesWritten = 0

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }

        engine.prepare()
        try engine.start()
        isCapturing = true
    }

    /// Stops writing and returns the finished file. Engine + session stay active.
    func finishCapture() -> CaptureResult? {
        guard isCapturing else { return nil }
        isCapturing = false
        engine.inputNode.removeTap(onBus: 0)

        guard let file else { return nil }
        let url = file.url
        let duration = Double(framesWritten) / targetFormat.sampleRate
        self.file = nil // closes the file
        converter = nil
        return CaptureResult(url: url, duration: duration)
    }

    /// Stops the engine and deactivates the audio session.
    func shutdown() {
        if isCapturing { _ = finishCapture() }
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard isCapturing, let converter, let file else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard conversionError == nil, output.frameLength > 0 else { return }

        do {
            try file.write(from: output)
            framesWritten += AVAudioFramePosition(output.frameLength)
        } catch {
            return
        }

        if let channel = output.floatChannelData?[0] {
            let count = Int(output.frameLength)
            var sum: Float = 0
            for i in 0 ..< count { sum += channel[i] * channel[i] }
            let rms = (sum / Float(max(count, 1))).squareRoot()
            onLevel?(min(1, rms * 8))
        }
    }
}
