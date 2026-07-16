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
        SharedModelStore.migrateLocalIfNeeded(model)
        let directory = SharedModelStore.directory(for: model)
        return AsrModels.modelsExist(at: directory, version: model.asrVersion)
    }

    func isLoaded(_ model: HexModel) -> Bool {
        loadedModel == model && asr != nil
    }

    func delete(_ model: HexModel) {
        try? FileManager.default.removeItem(at: SharedModelStore.directory(for: model))
        try? FileManager.default.removeItem(at: AsrModels.defaultCacheDirectory(for: model.asrVersion))
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

        SharedModelStore.migrateLocalIfNeeded(model)
        let targetDirectory = SharedModelStore.directory(for: model)

        // Real progress straight from FluidAudio (download AND compile phases) —
        // the old directory-size estimate assumed 650 MB and stalled at ~64 %
        // because the int8 encoder variant is only ~460 MB.
        let models = try await AsrModels.downloadAndLoad(
            to: targetDirectory,
            version: model.asrVersion,
            progressHandler: { snapshot in
                progress(min(0.98, max(0.02, snapshot.fractionCompleted)))
            }
        )
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
