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

/// The main intent for the Action Button (and Shortcuts/Siri): toggles dictation.
///
/// Headless-first strategy (same pattern as other shipping dictation apps):
/// `AudioRecordingIntent` lets us record in the background, but iOS mandates a
/// running Live Activity for that — and `Activity.request` from a background
/// launch is refused by ActivityKit in some situations ("Target is not
/// foreground"). So we TRY the fully headless start first; only when the Live
/// Activity cannot be started do we fall back to a brief foreground hop via
/// `ForegroundContinuableIntent` and start there. When the headless start
/// succeeds, the app never comes to the front at all.
struct ToggleDictationIntent: AudioRecordingIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Diktat starten/stoppen"
    static let description = IntentDescription(
        "Startet die Hex-Aufnahme bzw. stoppt sie und wandelt sie lokal auf dem Gerät in Text um.",
        categoryName: "Diktat"
    )
    static let openAppWhenRun = false

    /// Returns the transcript on stop (empty on start), so users can chain the
    /// intent in the Shortcuts app — e.g. with "Copy to Clipboard", which is
    /// allowed to write the pasteboard even though backgrounded apps are not.
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Stopping needs no Live Activity gymnastics — handle it first.
        if AppModel.shared.isRecording {
            await AppModel.shared.stopDictation()
            var text = ""
            if case let .done(transcript) = AppModel.shared.state {
                text = transcript.text
            }
            return .result(value: text)
        }

        // Without microphone permission, fail loudly (the system shows the
        // message as a banner) instead of failing silently in the background.
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw DictationIntentError.microphonePermissionMissing
        }

        let outcome = await AppModel.shared.startDictation()
        if outcome == .liveActivityUnavailable {
            // Headless start impossible right now — hop to the foreground, where
            // starting the Live Activity is always permitted, and retry there.
            try await requestToContinueInForeground {
                await AppModel.shared.waitUntilForeground()
                _ = await AppModel.shared.startDictation()
            }
        }
        return .result(value: "")
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
