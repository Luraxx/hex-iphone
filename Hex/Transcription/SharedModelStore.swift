import FluidAudio
import Foundation

/// One Parakeet download for ALL our apps: Hex and Lens share the model files
/// through a common App Group container, so 650 MB never exist twice on the
/// same iPhone. Falls back to the app-private FluidAudio default when the
/// group entitlement is missing (e.g. free-team signing hiccups).
enum SharedModelStore {
    static let groupID = "group.io.github.luraxx.models"

    static func directory(for model: HexModel) -> URL {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            return container
                .appendingPathComponent("FluidAudio/Models", isDirectory: true)
                .appendingPathComponent(model.identifier, isDirectory: true)
        }
        return AsrModels.defaultCacheDirectory(for: model.asrVersion)
    }

    /// One-time adoption: a model this app downloaded into its private
    /// container (before the shared group existed) is MOVED into the group —
    /// no copy, no double storage.
    static func migrateLocalIfNeeded(_ model: HexModel) {
        let shared = directory(for: model)
        let local = AsrModels.defaultCacheDirectory(for: model.asrVersion)
        guard shared.standardizedFileURL != local.standardizedFileURL,
              !AsrModels.modelsExist(at: shared, version: model.asrVersion),
              AsrModels.modelsExist(at: local, version: model.asrVersion)
        else { return }

        let fm = FileManager.default
        try? fm.createDirectory(at: shared.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fm.removeItem(at: shared)
        do {
            try fm.moveItem(at: local, to: shared)
        } catch {
            // Cross-container rename refused — fall back to copy + delete.
            if (try? fm.copyItem(at: local, to: shared)) != nil {
                try? fm.removeItem(at: local)
            }
        }
    }
}
