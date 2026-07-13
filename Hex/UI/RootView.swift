import HexShared
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @State private var showOnboarding = false
    @State private var copiedPulse = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 12)
                statusArea
                DictationButton()
                Spacer(minLength: 12)
                latestCard
            }
            .padding()
            .navigationTitle("Hex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .task {
            if !SharedSettings.didOnboard {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        VStack(spacing: 8) {
            switch model.state {
            case .idle:
                Text("Bereit")
                    .font(.title3.weight(.semibold))
                Text("Action Button drücken oder unten tippen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case let .recording(startedAt):
                Text(timerInterval: startedAt ... startedAt.addingTimeInterval(3600), countsDown: false)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("Ich höre zu — nochmal drücken zum Beenden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case .transcribing:
                ProgressView()
                    .controlSize(.large)
                Text("Transkribiere lokal auf dem Gerät …")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            case let .done(transcript):
                Label("Fertig", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)
                Text(transcript.text)
                    .font(.body)
                    .lineLimit(4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            case let .failed(message):
                Label("Fehler", systemImage: "exclamationmark.triangle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(minHeight: 130)
        .animation(.snappy, value: model.state)
    }

    @ViewBuilder
    private var latestCard: some View {
        if let latest = model.store.latest() {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Zuletzt")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(latest.createdAt, style: .relative)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                Text(latest.text)
                    .font(.callout)
                    .lineLimit(3)
                Button {
                    UIPasteboard.general.string = latest.text
                    copiedPulse = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copiedPulse = false
                    }
                } label: {
                    Label(copiedPulse ? "Kopiert" : "Kopieren", systemImage: copiedPulse ? "checkmark" : "doc.on.doc")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// The big record button with a level ring.
struct DictationButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            Task { await model.toggleDictation() }
        } label: {
            ZStack {
                Circle()
                    .fill(model.isRecording ? Color.red : Color.accentColor)
                    .frame(width: 104, height: 104)
                    .shadow(color: (model.isRecording ? Color.red : Color.accentColor).opacity(0.35), radius: 16, y: 6)

                if model.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.35), lineWidth: 4)
                        .frame(width: 124, height: 124)
                        .scaleEffect(1 + CGFloat(model.level) * 0.35)
                        .animation(.linear(duration: 0.1), value: model.level)
                }

                Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(model.state == .transcribing)
        .accessibilityLabel(model.isRecording ? "Aufnahme beenden" : "Aufnahme starten")
    }
}
