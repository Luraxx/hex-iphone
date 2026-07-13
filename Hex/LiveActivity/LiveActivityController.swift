import ActivityKit
import Foundation

/// Manages the recording Live Activity from within the app.
/// Important: when started via `AudioRecordingIntent`, a Live Activity MUST be
/// running, otherwise iOS stops the background recording.
@MainActor
final class LiveActivityController {
    private var activity: Activity<RecordingActivityAttributes>?

    func startRecording(startedAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endImmediately()

        let state = RecordingActivityAttributes.ContentState(
            phase: .recording,
            startedAt: startedAt,
            message: nil
        )
        activity = try? Activity.request(
            attributes: RecordingActivityAttributes(),
            content: ActivityContent(state: state, staleDate: nil)
        )
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
