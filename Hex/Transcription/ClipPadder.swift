import AVFoundation
import Foundation

/// FluidAudio's TDT decoder expects at least ~1.5 s of audio per clip.
/// Shorter recordings are padded with silence (ported from Hex/macOS).
enum ClipPadder {
    struct Result {
        let url: URL
        private let cleanupURL: URL?

        init(url: URL, cleanupURL: URL?) {
            self.url = url
            self.cleanupURL = cleanupURL
        }

        func cleanup() {
            guard let cleanupURL else { return }
            try? FileManager.default.removeItem(at: cleanupURL)
        }
    }

    enum PadError: LocalizedError {
        case unsupportedFormat
        case bufferAllocationFailed

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: "Aufnahmeformat wird nicht unterstützt (erwartet: mono Float32)."
            case .bufferAllocationFailed: "Audio-Puffer konnte nicht angelegt werden."
            }
        }
    }

    static let minimumDuration: TimeInterval = 1.5

    static func ensureMinimumDuration(url: URL) throws -> Result {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let duration = Double(audioFile.length) / format.sampleRate

        guard duration < minimumDuration else {
            return Result(url: url, cleanupURL: nil)
        }
        guard format.commonFormat == .pcmFormatFloat32 else {
            throw PadError.unsupportedFormat
        }

        let minimumFrames = AVAudioFrameCount((minimumDuration * format.sampleRate).rounded(.up))
        let sourceCapacity = AVAudioFrameCount(max(audioFile.length, 1))

        guard
            let readBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: sourceCapacity),
            let paddedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: minimumFrames)
        else {
            throw PadError.bufferAllocationFailed
        }

        try audioFile.read(into: readBuffer)
        let framesRead = min(readBuffer.frameLength, minimumFrames)

        guard
            let sourceChannels = readBuffer.floatChannelData,
            let paddedChannels = paddedBuffer.floatChannelData
        else {
            throw PadError.unsupportedFormat
        }

        for channel in 0 ..< Int(format.channelCount) {
            let destination = paddedChannels[channel]
            let source = sourceChannels[channel]
            if framesRead > 0 {
                destination.update(from: source, count: Int(framesRead))
            }
            let padCount = Int(minimumFrames - framesRead)
            if padCount > 0 {
                destination.advanced(by: Int(framesRead)).initialize(repeating: 0, count: padCount)
            }
        }
        paddedBuffer.frameLength = minimumFrames

        let paddedURL = url.deletingPathExtension().appendingPathExtension("padded.wav")
        try? FileManager.default.removeItem(at: paddedURL)

        let paddedFile = try AVAudioFile(forWriting: paddedURL, settings: audioFile.fileFormat.settings)
        try paddedFile.write(from: paddedBuffer)

        return Result(url: paddedURL, cleanupURL: paddedURL)
    }
}
