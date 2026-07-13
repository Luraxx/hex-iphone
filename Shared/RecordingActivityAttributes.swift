import ActivityKit
import Foundation

/// State of the recording Live Activity (Dynamic Island + lock screen).
/// This file is compiled into BOTH the app and the widget target.
struct RecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case recording
            case transcribing
            case done
            case failed
        }

        var phase: Phase
        var startedAt: Date
        var message: String?
    }
}
