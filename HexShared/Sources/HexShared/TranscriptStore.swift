import Foundation

/// File-based store in the App Group container.
/// Written by the app, read/consumed by the keyboard.
public final class TranscriptStore: @unchecked Sendable {
    public static let shared = TranscriptStore()

    private let queue = DispatchQueue(label: "io.github.luraxx.hex.transcriptstore")
    private let baseURL: URL?

    /// Transcript queued for auto-insertion.
    public struct Pending: Codable, Sendable {
        public var id: UUID
        public var text: String
        public var createdAt: Date
        public var consumed: Bool

        public init(id: UUID, text: String, createdAt: Date, consumed: Bool = false) {
            self.id = id
            self.text = text
            self.createdAt = createdAt
            self.consumed = consumed
        }
    }

    public init(appGroupID: String = SharedConstants.appGroupID) {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let dir = container.appendingPathComponent("HexStore", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            baseURL = dir
        } else {
            baseURL = nil
        }
    }

    /// true when the App Group container is reachable (signing/full access set up correctly).
    public var isAvailable: Bool { baseURL != nil }

    private var transcriptsURL: URL? { baseURL?.appendingPathComponent("transcripts.json") }
    private var pendingURL: URL? { baseURL?.appendingPathComponent("pending.json") }

    // MARK: - History

    public func all() -> [Transcript] {
        queue.sync { readTranscripts() }
    }

    public func latest() -> Transcript? {
        queue.sync { readTranscripts().first }
    }

    public func append(_ transcript: Transcript, keep: Int = 200) {
        queue.sync {
            var list = readTranscripts()
            list.insert(transcript, at: 0)
            if list.count > keep { list = Array(list.prefix(keep)) }
            writeTranscripts(list)
        }
    }

    public func delete(id: UUID) {
        queue.sync {
            var list = readTranscripts()
            list.removeAll { $0.id == id }
            writeTranscripts(list)
        }
    }

    public func deleteAll() {
        queue.sync { writeTranscripts([]) }
    }

    // MARK: - Pending (auto-insertion by the keyboard)

    public func setPending(_ transcript: Transcript) {
        queue.sync {
            let pending = Pending(id: transcript.id, text: transcript.text, createdAt: transcript.createdAt)
            writePending(pending)
        }
    }

    /// Returns the unconsumed transcript if it is younger than `maxAge` seconds.
    public func pendingForInsertion(maxAge: TimeInterval = 300) -> Pending? {
        queue.sync {
            guard let pending = readPending(),
                  !pending.consumed,
                  Date.now.timeIntervalSince(pending.createdAt) < maxAge
            else { return nil }
            return pending
        }
    }

    public func markPendingConsumed(id: UUID) {
        queue.sync {
            guard var pending = readPending(), pending.id == id else { return }
            pending.consumed = true
            writePending(pending)
        }
    }

    // MARK: - File access

    private func readTranscripts() -> [Transcript] {
        guard let url = transcriptsURL, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Transcript].self, from: data)) ?? []
    }

    private func writeTranscripts(_ list: [Transcript]) {
        guard let url = transcriptsURL, let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func readPending() -> Pending? {
        guard let url = pendingURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Pending.self, from: data)
    }

    private func writePending(_ pending: Pending) {
        guard let url = pendingURL, let data = try? JSONEncoder().encode(pending) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
