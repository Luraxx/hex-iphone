import AppIntents

/// The main intent for the Action Button (and Shortcuts/Siri): opens Hex and
/// toggles dictation (start, or stop + transcribe).
///
/// Why it opens the app instead of recording in the background: iOS refuses to
/// start a Live Activity from the background ("Target is not foreground"), and an
/// `AudioRecordingIntent` that activates the mic without a Live Activity is
/// hard-crashed by the system. So this is a plain `AppIntent` with
/// `openAppWhenRun = true`: it brings Hex to the foreground, where recording and
/// the Live Activity start reliably. Recording then continues via the audio
/// background mode after you leave the app, and can be stopped from the Dynamic
/// Island ("Fertig") or by pressing the Action Button again.
struct ToggleDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Diktat starten/stoppen"
    static let description = IntentDescription(
        "Öffnet Hex und startet die Aufnahme bzw. stoppt sie und wandelt sie lokal auf dem Gerät in Text um.",
        categoryName: "Diktat"
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        await AppModel.shared.handleActionButton()
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
