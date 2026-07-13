import Foundation

/// A finished transcript in the history.
public struct Transcript: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var text: String
    public var createdAt: Date
    /// Recording duration in seconds.
    public var duration: TimeInterval
    /// Identifier of the model used for transcription (e.g. parakeet-tdt-0.6b-v3-coreml).
    public var modelID: String

    public init(id: UUID = UUID(), text: String, createdAt: Date = .now, duration: TimeInterval, modelID: String) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.duration = duration
        self.modelID = modelID
    }
}
