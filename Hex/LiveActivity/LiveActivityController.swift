import ActivityKit
import Foundation
import UIKit

/// Manages the recording Live Activity from within the app.
///
/// Core trick for headless (no app opening) starts: ActivityKit refuses to
/// START a Live Activity from the background ("Target is not foreground"), but
/// UPDATING an existing one is allowed anytime. So while enabled in settings we
/// keep a quiet "ready" activity alive whenever the app is foregrounded, and a
/// background start (Action Button) merely flips it to the recording state.
/// iOS's AudioRecordingIntent policy ("active audio session requires a Live
/// Activity") is satisfied by the existing activity.
@MainActor
final class LiveActivityController {
    private var activity: Activity<RecordingActivityAttributes>?
    /// Human-readable reason the last start attempt failed (surfaced for diagnosis).
    private(set) var lastStartError: String?

    var hasActivity: Bool {
        if let activity, activity.activityState == .active { return true }
        return false
    }

    /// Adopts an activity that survived an app restart (or ends duplicates).
    func adoptExistingActivity() {
        let existing = Activity<RecordingActivityAttributes>.activities
        activity = existing.first
        guard existing.count > 1 else { return }
        for stale in existing.dropFirst() {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Ensures the quiet "ready" activity exists. Only possible in the foreground —
    /// call on scene activation and after a dictation finishes in the foreground.
    func ensureReadyActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        adoptExistingActivity()
        let state = RecordingActivityAttributes.ContentState(phase: .ready, startedAt: .now, message: nil)
        if let activity {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }
        guard UIApplication.shared.applicationState == .active else { return }
        activity = try? Activity.request(
            attributes: RecordingActivityAttributes(),
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    /// Removes the standby activity (setting turned off).
    func endReadyActivity() {
        guard let activity, activity.content.state.phase == .ready else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// Returns true only if a Live Activity is running afterwards. The caller
    /// MUST NOT activate the microphone in the background when this returns false —
    /// iOS hard-crashes an AudioRecordingIntent with active audio but no Live Activity.
    @discardableResult
    func startRecording(startedAt: Date) -> Bool {
        lastStartError = nil
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            lastStartError = "Live-Aktivitäten sind für Hex ausgeschaltet. Bitte in Einstellungen → Hex → „Live-Aktivitäten“ einschalten."
            return false
        }
        adoptExistingActivity()

        let state = RecordingActivityAttributes.ContentState(
            phase: .recording,
            startedAt: startedAt,
            message: nil
        )
        // Preferred path: update the existing (usually "ready") activity —
        // this is what makes fully headless background starts possible.
        if let activity {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
            return true
        }
        // No standby activity: requesting a fresh one only works in the foreground.
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

    /// Shows the final state for `seconds`, then returns to standby (or ends the
    /// activity when the standby indicator is disabled in settings).
    func finish(phase: RecordingActivityAttributes.ContentState.Phase, message: String?, after seconds: TimeInterval, keepReady: Bool) async {
        guard let activity else { return }
        var state = activity.content.state
        state.phase = phase
        state.message = message
        await activity.update(ActivityContent(state: state, staleDate: nil))

        let activityAtFinish = activity
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            // Only transition if nothing newer took over in the meantime.
            guard activityAtFinish.content.state.phase == phase else { return }
            if keepReady {
                var readyState = activityAtFinish.content.state
                readyState.phase = .ready
                readyState.message = nil
                await activityAtFinish.update(ActivityContent(state: readyState, staleDate: nil))
            } else {
                await MainActor.run { self.activity = nil }
                await activityAtFinish.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Instant transition back to standby (cancel, discarded capture, start failure).
    func revertToReadyOrEnd(keepReady: Bool) {
        guard let activity else { return }
        if keepReady {
            var state = activity.content.state
            state.phase = .ready
            state.message = nil
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        } else {
            endImmediately()
        }
    }

    func endImmediately() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
