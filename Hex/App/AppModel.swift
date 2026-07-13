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

    func startDictation() async {
        guard !isRecording, state != .transcribing else { return }
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            break
        case .undetermined:
            guard await AVAudioApplication.requestRecordPermission() else {
                state = .failed("Ohne Mikrofon-Zugriff kann Hex nicht aufnehmen.")
                return
            }
        default:
            state = .failed("Mikrofon-Zugriff fehlt. Bitte in den iOS-Einstellungen für Hex erlauben.")
            return
        }

        do {
            let startedAt = Date.now
            // Start the Live Activity FIRST. When the Action Button launches us into
            // the background, iOS keeps an AudioRecordingIntent alive only while a
            // Live Activity is running — establish it before touching the audio engine.
            liveActivity.startRecording(startedAt: startedAt)
            // Hold a background assertion so the cold background launch is not
            // suspended in the moment before the audio session becomes active.
            beginBackgroundWork()
            try recorder.startCapture(to: Self.recordingURL())
            state = .recording(startedAt: startedAt)
            lastError = nil
            Feedback.recordStart()
            DarwinNotify.post(SharedConstants.Darwin.recordingStateChanged)

            // NOTE: the ~650 MB model is deliberately NOT preloaded here. On a cold
            // background launch (Action Button) that memory spike gets the process
            // jetsammed mid-recording. It is loaded lazily at stop time instead, where
            // the still-active audio session + Live Activity keep us alive with a
            // proper memory budget.

            // Safety net against forgotten recordings.
            let capMinutes = max(1, SharedSettings.maxMinutes)
            maxDurationTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Double(capMinutes) * 60))
                guard !Task.isCancelled else { return }
                await self?.stopDictation()
            }
        } catch {
            liveActivity.endImmediately()
            recorder.shutdown()
            finishBackgroundWork()
            state = .failed(error.localizedDescription)
            Feedback.error()
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
            liveActivity.endImmediately()
            finishBackgroundWork()
            return
        }

        // Ignore accidental short triggers (like "ignore under 0.3 s" in Hex).
        if capture.duration < SharedSettings.minDuration {
            recorder.shutdown()
            cleanup(capture.url)
            state = .idle
            await liveActivity.end(phase: .done, message: "Zu kurz, verworfen", after: 2)
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
                await liveActivity.end(phase: .done, message: "Nichts erkannt", after: 3)
            } else {
                let transcript = Transcript(text: text, duration: capture.duration, modelID: model.identifier)
                store.append(transcript)
                store.setPending(transcript)
                if SharedSettings.autoCopy {
                    UIPasteboard.general.string = text
                }
                state = .done(transcript)
                Feedback.done()
                DarwinNotify.post(SharedConstants.Darwin.newTranscript)
                let suffix = SharedSettings.autoCopy ? " — kopiert" : ""
                await liveActivity.end(phase: .done, message: String(text.prefix(80)) + suffix, after: 4)
            }
            refreshDownloadedModels()
        } catch {
            recorder.shutdown()
            cleanup(capture.url)
            state = .failed(error.localizedDescription)
            Feedback.error()
            await liveActivity.end(phase: .failed, message: error.localizedDescription, after: 6)
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
        liveActivity.endImmediately()
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
