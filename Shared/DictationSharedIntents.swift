import AppIntents
import Foundation

/// Bridge between intents and the app logic. The widget target compiles this
/// file only so the Live Activity buttons know the intent types —
/// LiveActivityIntents always execute in the app's process, where AppModel
/// registers itself as the performer at launch.
@MainActor
protocol DictationPerforming: AnyObject {
    func toggleDictation() async
    func stopDictation() async
    func cancelDictation() async
}

@MainActor
enum DictationBridge {
    static var performer: (any DictationPerforming)?
}

/// Stops the current recording and transcribes it (Live Activity button).
struct StopDictationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Diktat beenden"
    static let description = IntentDescription("Beendet die laufende Hex-Aufnahme und wandelt sie in Text um.")
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await DictationBridge.performer?.stopDictation()
        return .result()
    }
}

/// Discards the current recording without transcribing (Live Activity button).
struct CancelDictationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Diktat verwerfen"
    static let description = IntentDescription("Verwirft die laufende Hex-Aufnahme.")
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await DictationBridge.performer?.cancelDictation()
        return .result()
    }
}
