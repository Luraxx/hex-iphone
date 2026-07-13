import AppIntents
import AVFoundation

enum DictationIntentError: Error, CustomLocalizedStringResourceConvertible {
    case microphonePermissionMissing

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .microphonePermissionMissing:
            "Bitte öffne Hex einmal und erlaube den Mikrofon-Zugriff."
        }
    }
}

/// The main intent for the Action Button (and Shortcuts/Siri):
/// starts dictation, or stops it and transcribes.
///
/// `AudioRecordingIntent` (iOS 18+) allows starting the recording WITHOUT
/// bringing the app to the foreground — the condition is that a Live Activity
/// starts immediately (AppModel does this when recording starts).
struct ToggleDictationIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Diktat starten/stoppen"
    static let description = IntentDescription(
        "Startet die Hex-Aufnahme bzw. stoppt sie und wandelt sie lokal auf dem Gerät in Text um.",
        categoryName: "Diktat"
    )
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        // Without microphone permission, fail loudly (the system shows the
        // message as a banner) instead of failing silently in the background.
        if !AppModel.shared.isRecording,
           AVAudioApplication.shared.recordPermission != .granted {
            throw DictationIntentError.microphonePermissionMissing
        }
        await AppModel.shared.toggleDictation()
        return .result()
    }
}

/// Surfaces the intent in the Action Button picker (Settings → Action Button
/// → Shortcut) and in Spotlight without any manual setup.
struct HexAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleDictationIntent(),
            phrases: [
                "\(.applicationName) Diktat",
                "Diktiere mit \(.applicationName)",
                "Starte \(.applicationName) Diktat",
                "Toggle \(.applicationName) dictation",
            ],
            shortTitle: "Diktat",
            systemImageName: "mic.fill"
        )
    }
}
