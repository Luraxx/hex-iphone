import FluidAudio
import Foundation

enum EngineError: LocalizedError {
    case notLoaded

    var errorDescription: String? {
        switch self {
        case .notLoaded: "Modell ist nicht geladen."
        }
    }
}

/// Manages the Parakeet models via FluidAudio: download, load, transcribe.
/// API usage identical to Hex (macOS) with FluidAudio 0.15.5.
actor ParakeetEngine {
    static let shared = ParakeetEngine()

    private var asr: AsrManager?
    private var loadedModel: HexModel?

    // MARK: - Model management

    func isDownloaded(_ model: HexModel) -> Bool {
        let directory = AsrModels.defaultCacheDirectory(for: model.asrVersion)
        return AsrModels.modelsExist(at: directory, version: model.asrVersion)
    }

    func isLoaded(_ model: HexModel) -> Bool {
        loadedModel == model && asr != nil
    }

    func delete(_ model: HexModel) {
        let directory = AsrModels.defaultCacheDirectory(for: model.asrVersion)
        try? FileManager.default.removeItem(at: directory)
        if loadedModel == model {
            asr = nil
            loadedModel = nil
        }
    }

    private var loadTask: Task<Void, Error>?
    private var loadingModel: HexModel?

    /// Loads (and downloads if needed) the model. Progress 0...1, best effort:
    /// FluidAudio reports no download progress, so — like Hex — the directory
    /// size is polled against the target size (~650 MB).
    ///
    /// Concurrent callers share one in-flight load: the actor is reentrant at
    /// suspension points, so without deduplication the preload (recording start)
    /// and the transcription (stop) would compile the CoreML models twice in
    /// parallel — the device logs showed exactly that (~27 s, twice).
    func ensureLoaded(_ model: HexModel, progress: @escaping @Sendable (Double) -> Void) async throws {
        if isLoaded(model) {
            progress(1)
            return
        }
        if let running = loadTask, loadingModel == model {
            try await running.value
            progress(1)
            return
        }

        loadTask?.cancel()
        asr = nil
        loadedModel = nil
        loadingModel = model
        let task = Task { try await self.performLoad(model, progress: progress) }
        loadTask = task
        defer {
            if loadingModel == model {
                loadTask = nil
                loadingModel = nil
            }
        }
        try await task.value
    }

    private func performLoad(_ model: HexModel, progress: @escaping @Sendable (Double) -> Void) async throws {
        progress(0.02)

        let needsDownload = !isDownloaded(model)
        var pollTask: Task<Void, Never>?
        if needsDownload {
            let directory = downloadDirectory(for: model)
            pollTask = Task.detached {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if let size = Self.directorySize(directory) {
                        let target = 650.0 * 1024 * 1024
                        let fraction = min(0.9, max(0.02, Double(size) / target * 0.9))
                        progress(fraction)
                    }
                }
            }
        } else {
            progress(0.5)
        }
        defer { pollTask?.cancel() }

        let models = try await AsrModels.downloadAndLoad(version: model.asrVersion)
        let manager = AsrManager(config: .init(), models: models)
        asr = manager
        loadedModel = model
        progress(1)
    }

    // MARK: - Transcription

    func transcribe(url: URL, model: HexModel) async throws -> String {
        if !isLoaded(model) {
            try await ensureLoaded(model, progress: { _ in })
        }
        guard let asr else { throw EngineError.notLoaded }

        let prepared = try ClipPadder.ensureMinimumDuration(url: url)
        defer { prepared.cleanup() }

        var decoderState = TdtDecoderState.make(decoderLayers: await asr.decoderLayerCount)
        let result = try await asr.transcribe(prepared.url, decoderState: &decoderState)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    /// FluidAudio stores models under Application Support/FluidAudio/Models/<id>.
    private func downloadDirectory(for model: HexModel) -> URL {
        AsrModels.defaultCacheDirectory(for: model.asrVersion)
    }

    private static func directorySize(_ directory: URL) -> UInt64? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var total: UInt64 = 0
        for case let url as URL in enumerator {
            if let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
               values.isRegularFile == true {
                total &+= UInt64(values.fileSize ?? 0)
            }
        }
        return total
    }
}
