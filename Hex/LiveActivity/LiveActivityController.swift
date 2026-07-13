import ActivityKit
import Foundation

/// Manages the recording Live Activity from within the app.
/// Important: when started via `AudioRecordingIntent`, a Live Activity MUST be
/// running, otherwise iOS stops the background recording.
@MainActor
final class LiveActivityController {
    private var activity: Activity<RecordingActivityAttributes>?
    /// Human-readable reason the last start attempt failed (surfaced in-app for diagnosis).
    private(set) var lastStartError: String?

    /// Returns true only if a Live Activity is actually running afterwards. The caller
    /// MUST NOT activate the microphone when this returns false in the background —
    /// iOS hard-crashes an AudioRecordingIntent that has active audio but no Live Activity.
    @discardableResult
    func startRecording(startedAt: Date) -> Bool {
        lastStartError = nil
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            lastStartError = "Live-Aktivitäten sind für Hex ausgeschaltet. Bitte in Einstellungen → Hex → „Live-Aktivitäten“ einschalten."
            return false
        }
        endImmediately()

        let state = RecordingActivityAttributes.ContentState(
            phase: .recording,
            startedAt: startedAt,
            message: nil
        )
        do {
            activity = try Activity.request(
                attributes: RecordingActivityAttributes(),
                content: ActivityContent(state: state, staleDate: nil)
            )
            return true
        } catch {
            activity = nil
            lastStartError = "Live-Aktivität ließ sich nicht starten: \(error.localizedDescription)"
            return false
        }
    }

    func update(phase: RecordingActivityAttributes.ContentState.Phase, message: String?) async {
        guard let activity else { return }
        var state = activity.content.state
        state.phase = phase
        state.message = message
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    /// Shows the final state for `seconds`, then cleans up.
    func end(phase: RecordingActivityAttributes.ContentState.Phase, message: String?, after seconds: TimeInterval) async {
        guard let activity else { return }
        self.activity = nil
        var state = activity.content.state
        state.phase = phase
        state.message = message
        let content = ActivityContent(state: state, staleDate: nil)
        await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(seconds)))
    }

    func endImmediately() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
