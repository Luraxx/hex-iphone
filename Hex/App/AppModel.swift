import AVFoundation
import Foundation
import HexShared
import SwiftUI
import UIKit

/// Central state machine: recording → transcription → history/clipboard.
/// Driven by the UI as well as by App Intents (Action Button,
/// Live Activity buttons) via `DictationBridge`.
@MainActor
@Observable
final class AppModel: DictationPerforming {
    static let shared = AppModel()

    enum DictationState: Equatable {
        case idle
        case recording(startedAt: Date)
        case transcribing
        case done(Transcript)
        case failed(String)
    }

    private(set) var state: DictationState = .idle
    private(set) var level: Float = 0

    let store = TranscriptStore.shared

    // Model management for the settings UI
    private(set) var downloadedModels: Set<HexModel> = []
    private(set) var downloadProgress: [HexModel: Double] = [:]
    var lastError: String?

    private let recorder = AudioRecorder()
    private let liveActivity = LiveActivityController()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var maxDurationTask: Task<Void, Never>?
    private var preloadTask: Task<Void, Never>?
    /// Set when the auto-copy happened in the background, where iOS may reject
    /// pasteboard writes ("Pasteboard ... is not available at this time") —
    /// retried the next time the app becomes active.
    private var clipboardCopyPending = false

    private init() {
        DictationBridge.performer = self
        recorder.onLevel = { [weak self] newLevel in
            Task { @MainActor in self?.level = newLevel }
        }
        observeInterruptions()
        refreshDownloadedModels()
    }

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var recordingStartedAt: Date? {
        if case let .recording(startedAt) = state { return startedAt }
        return nil
    }

    // MARK: - DictationPerforming (Intents + UI)

    enum StartOutcome {
        case started
        /// Background start refused because the mandatory Live Activity could not
        /// be started ("Target is not foreground"). The intent reacts with a brief
        /// foreground hop and retries.
        case liveActivityUnavailable
        case failed
    }

    /// Used by the intent after `requestToContinueInForeground` — gives the app a
    /// moment to actually become active before retrying the start.
    func waitUntilForeground() async {
        for _ in 0 ..< 50 {
            if UIApplication.shared.applicationState == .active { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Called on every scene activation: refreshes the standby Live Activity
    /// (start is only allowed in the foreground) and retries a clipboard copy
    /// that iOS rejected while we were in the background.
    func appBecameActive() {
        if SharedSettings.readyIndicator {
            liveActivity.ensureReadyActivity()
        }
        if clipboardCopyPending, SharedSettings.autoCopy, let latest = store.latest() {
            UIPasteboard.general.string = latest.text
            clipboardCopyPending = false
        }
        refreshDownloadedModels()
    }

    /// Settings toggle for the standby indicator in the Dynamic Island.
    func setReadyIndicator(_ enabled: Bool) {
        SharedSettings.readyIndicator = enabled
        if enabled {
            liveActivity.ensureReadyActivity()
        } else if !isRecording, state != .transcribing {
            liveActivity.endReadyActivity()
        }
    }

    func toggleDictation() async {
        switch state {
        case .recording:
            await stopDictation()
        case .transcribing:
            break
        default:
            await startDictation()
        }
    }

    @discardableResult
    func startDictation() async -> StartOutcome {
        guard !isRecording, state != .transcribing else { return .failed }
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            break
        case .undetermined:
            guard await AVAudioApplication.requestRecordPermission() else {
                state = .failed("Ohne Mikrofon-Zugriff kann Hex nicht aufnehmen.")
                return .failed
            }
        default:
            state = .failed("Mikrofon-Zugriff fehlt. Bitte in den iOS-Einstellungen für Hex erlauben.")
            return .failed
        }

        let startedAt = Date.now
        // Start the Live Activity FIRST and confirm it is actually running. iOS
        // HARD-CRASHES an AudioRecordingIntent that has an active audio session
        // without a running Live Activity (and leaves the mic stuck on). So in the
        // background we only touch the mic when the Live Activity is up; otherwise
        // we report .liveActivityUnavailable and the intent retries after a brief
        // foreground hop. In the foreground the Live Activity is optional.
        var liveActivityStarted = liveActivity.startRecording(startedAt: startedAt)
        if !liveActivityStarted, UIApplication.shared.applicationState != .active {
            return .liveActivityUnavailable
        }

        do {
            // Hold a background assertion so the cold background launch is not
            // suspended in the moment before the audio session becomes active.
            beginBackgroundWork()
            try recorder.startCapture(to: Self.recordingURL())
            state = .recording(startedAt: startedAt)
            lastError = nil
            Feedback.recordStart()
            DarwinNotify.post(SharedConstants.Darwin.recordingStateChanged)

            // Foreground start whose Live Activity failed on the first try: retry
            // once now that the audio session is active. Recording in the background
            // without a Live Activity would crash a later Action Button stop.
            if !liveActivityStarted, UIApplication.shared.applicationState == .active {
                liveActivityStarted = liveActivity.startRecording(startedAt: startedAt)
            }

            // Warm up the model WHILE recording (first cold load compiles CoreML for
            // ~30 s — done here it overlaps with speaking instead of delaying the
            // result after stop). The device-log jetsam fear proved unfounded; the
            // earlier crash was the Live Activity assertion.
            let model = HexModel.selected
            preloadTask = Task.detached(priority: .userInitiated) {
                try? await ParakeetEngine.shared.ensureLoaded(model, progress: { _ in })
            }

            // Safety net against forgotten recordings.
            let capMinutes = max(1, SharedSettings.maxMinutes)
            maxDurationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Double(capMinutes) * 60))
                guard !Task.isCancelled else { return }
                await self?.stopDictation()
            }
            return .started
        } catch {
            liveActivity.revertToReadyOrEnd(keepReady: SharedSettings.readyIndicator)
            recorder.shutdown()
            finishBackgroundWork()
            state = .failed(error.localizedDescription)
            Feedback.error()
            return .failed
        }
    }

    func stopDictation() async {
        guard case .recording = state else { return }
        maxDurationTask?.cancel()
        beginBackgroundWork()
        Feedback.recordStop()

        guard let capture = recorder.finishCapture() else {
            recorder.shutdown()
            state = .idle
            liveActivity.revertToReadyOrEnd(keepReady: SharedSettings.readyIndicator)
            finishBackgroundWork()
            return
        }

        // Ignore accidental short triggers (like "ignore under 0.3 s" in Hex).
        if capture.duration < SharedSettings.minDuration {
            recorder.shutdown()
            cleanup(capture.url)
            state = .idle
            await liveActivity.finish(phase: .done, message: "Zu kurz, verworfen", after: 2, keepReady: SharedSettings.readyIndicator)
            DarwinNotify.post(SharedConstants.Darwin.recordingStateChanged)
            finishBackgroundWork()
            return
        }

        state = .transcribing
        await liveActivity.update(phase: .transcribing, message: nil)

        let model = HexModel.selected
        do {
            let text = try await ParakeetEngine.shared.transcribe(url: capture.url, model: model)
            recorder.shutdown()
            cleanup(capture.url)

            if text.isEmpty {
                state = .idle
                await liveActivity.finish(phase: .done, message: "Nichts erkannt", after: 3, keepReady: SharedSettings.readyIndicator)
            } else {
                let transcript = Transcript(text: text, duration: capture.duration, modelID: model.identifier)
                store.append(transcript)
                store.setPending(transcript)
                if SharedSettings.autoCopy {
                    UIPasteboard.general.string = text
                    clipboardCopyPending = UIApplication.shared.applicationState != .active
                }
                state = .done(transcript)
                Feedback.done()
                DarwinNotify.post(SharedConstants.Darwin.newTranscript)
                let suffix = SharedSettings.autoCopy ? " — kopiert" : ""
                await liveActivity.finish(phase: .done, message: String(text.prefix(80)) + suffix, after: 4, keepReady: SharedSettings.readyIndicator)
            }
            refreshDownloadedModels()
        } catch {
            recorder.shutdown()
            cleanup(capture.url)
            state = .failed(error.localizedDescription)
            Feedback.error()
            await liveActivity.finish(phase: .failed, message: error.localizedDescription, after: 6, keepReady: SharedSettings.readyIndicator)
        }
        DarwinNotify.post(SharedConstants.Darwin.recordingStateChanged)
        finishBackgroundWork()
    }

    func cancelDictation() async {
        guard case .recording = state else { return }
        maxDurationTask?.cancel()
        if let capture = recorder.finishCapture() {
            cleanup(capture.url)
        }
        recorder.shutdown()
        state = .idle
        liveActivity.revertToReadyOrEnd(keepReady: SharedSettings.readyIndicator)
        DarwinNotify.post(SharedConstants.Darwin.recordingStateChanged)
    }

    func dismissResult() {
        if case .done = state { state = .idle }
        if case .failed = state { state = .idle }
    }

    // MARK: - Model management (settings)

    func refreshDownloadedModels() {
        Task {
            var downloaded = Set<HexModel>()
            for model in HexModel.allCases {
                if await ParakeetEngine.shared.isDownloaded(model) {
                    downloaded.insert(model)
                }
            }
            downloadedModels = downloaded
        }
    }

    func downloadModel(_ model: HexModel) {
        guard downloadProgress[model] == nil else { return }
        downloadProgress[model] = 0.01
        Task {
            do {
                try await ParakeetEngine.shared.ensureLoaded(model) { fraction in
                    Task { @MainActor in
                        AppModel.shared.downloadProgress[model] = fraction
                    }
                }
                downloadProgress[model] = nil
                downloadedModels.insert(model)
            } catch {
                downloadProgress[model] = nil
                lastError = "Download fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    func deleteModel(_ model: HexModel) {
        Task {
            await ParakeetEngine.shared.delete(model)
            downloadedModels.remove(model)
        }
    }

    // MARK: - Internals

    private static func recordingURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("hex-recording.wav")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func beginBackgroundWork() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "hex.transcribe") { [weak self] in
            Task { @MainActor in self?.finishBackgroundWork() }
        }
    }

    private func finishBackgroundWork() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { note in
            guard
                let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                AVAudioSession.InterruptionType(rawValue: raw) == .began
            else { return }
            Task { @MainActor in
                if AppModel.shared.isRecording {
                    await AppModel.shared.stopDictation()
                }
            }
        }
    }
}
