import ActivityKit
import Foundation

/// State of the recording Live Activity (Dynamic Island + lock screen).
/// This file is compiled into BOTH the app and the widget target.
struct RecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            /// Standby: a persistent, quiet activity that exists so a background
            /// start only needs to UPDATE it (allowed anytime) instead of
            /// requesting a new one (forbidden from the background).
            case ready
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
