import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

extension RecordingActivityAttributes.ContentState.Phase {
    var label: String {
        switch self {
        case .ready: "Bereit"
        case .recording: "Höre zu …"
        case .transcribing: "Transkribiere …"
        case .done: "Fertig"
        case .failed: "Fehler"
        }
    }

    var symbol: String {
        switch self {
        case .ready: "hexagon"
        case .recording: "mic.fill"
        case .transcribing: "ellipsis"
        case .done: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ready: .secondary
        case .recording: .red
        case .transcribing: .secondary
        case .done: .green
        case .failed: .yellow
        }
    }
}

private func timerRange(from startedAt: Date) -> ClosedRange<Date> {
    startedAt ... startedAt.addingTimeInterval(60 * 60)
}

struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            LockScreenActivityView(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.7))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.phase.label, systemImage: context.state.phase.symbol)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(context.state.phase.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.phase == .recording {
                        Text(timerInterval: timerRange(from: context.state.startedAt), countsDown: false)
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                            .frame(maxWidth: 60)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    switch context.state.phase {
                    case .ready:
                        Button(intent: StartDictationFromActivityIntent()) {
                            Label("Aufnehmen", systemImage: "mic.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    case .recording:
                        HStack(spacing: 12) {
                            Button(intent: CancelDictationIntent()) {
                                Label("Verwerfen", systemImage: "xmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.gray)

                            Button(intent: StopDictationIntent()) {
                                Label("Fertig", systemImage: "checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    case .transcribing:
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Wandle Sprache in Text um …")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    case .done, .failed:
                        if let message = context.state.message {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.phase.symbol)
                    .foregroundStyle(context.state.phase.tint)
            } compactTrailing: {
                if context.state.phase == .recording {
                    Text(timerInterval: timerRange(from: context.state.startedAt), countsDown: false)
                        .monospacedDigit()
                        .font(.caption2)
                        .frame(maxWidth: 44)
                        .foregroundStyle(.red)
                } else {
                    EmptyView()
                }
            } minimal: {
                Image(systemName: context.state.phase.symbol)
                    .foregroundStyle(context.state.phase.tint)
            }
        }
    }
}

private struct LockScreenActivityView: View {
    let state: RecordingActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(state.phase.label, systemImage: state.phase.symbol)
                    .font(.headline)
                    .foregroundStyle(state.phase.tint)
                Spacer()
                if state.phase == .recording {
                    Text(timerInterval: timerRange(from: state.startedAt), countsDown: false)
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }

            switch state.phase {
            case .ready:
                Button(intent: StartDictationFromActivityIntent()) {
                    Label("Aufnehmen", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            case .recording:
                HStack(spacing: 12) {
                    Button(intent: CancelDictationIntent()) {
                        Label("Verwerfen", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    Button(intent: StopDictationIntent()) {
                        Label("Fertig", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            case .transcribing:
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Wandle Sprache in Text um …")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                }
            case .done, .failed:
                if let message = state.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
        }
    }
}
