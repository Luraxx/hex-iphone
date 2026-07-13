import HexShared
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var selectedModelID = SharedSettings.selectedModelID
    @State private var autoCopy = SharedSettings.autoCopy
    @State private var autoInsert = SharedSettings.autoInsert
    @State private var soundEffects = SharedSettings.soundEffects
    @State private var haptics = SharedSettings.haptics
    @State private var minDuration = SharedSettings.minDuration
    @State private var maxMinutes = SharedSettings.maxMinutes
    @State private var readyIndicator = SharedSettings.readyIndicator

    var body: some View {
        List {
            Section("Transkriptionsmodell") {
                ForEach(HexModel.allCases) { hexModel in
                    ModelRow(
                        hexModel: hexModel,
                        isSelected: selectedModelID == hexModel.identifier,
                        isDownloaded: model.downloadedModels.contains(hexModel),
                        progress: model.downloadProgress[hexModel],
                        select: {
                            selectedModelID = hexModel.identifier
                            SharedSettings.selectedModelID = hexModel.identifier
                            if !model.downloadedModels.contains(hexModel) {
                                model.downloadModel(hexModel)
                            }
                        },
                        download: { model.downloadModel(hexModel) },
                        delete: { model.deleteModel(hexModel) }
                    )
                }
                if let error = model.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Diktat") {
                Toggle("In Zwischenablage kopieren", isOn: $autoCopy)
                Toggle("Hex-Tastatur fügt automatisch ein", isOn: $autoInsert)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Bereitschafts-Anzeige", isOn: $readyIndicator)
                    Text("Hält ein kleines Hex-Symbol in der Dynamic Island. Nur damit kann der Action Button die Aufnahme starten, ohne die App zu öffnen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Soundeffekte", isOn: $soundEffects)
                Toggle("Haptik", isOn: $haptics)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unter \(minDuration, format: .number.precision(.fractionLength(1))) s ignorieren")
                    Slider(value: $minDuration, in: 0 ... 2, step: 0.1)
                }
                Stepper("Max. Aufnahme: \(maxMinutes) min", value: $maxMinutes, in: 1 ... 30)
            }

            Section("Einrichtung") {
                NavigationLink {
                    SetupGuideView()
                } label: {
                    Label("Action Button & Tastatur einrichten", systemImage: "wand.and.stars")
                }
            }

            Section("Über") {
                LabeledContent("Version", value: "1.0 (1)")
                LabeledContent("Engine", value: "FluidAudio · Parakeet TDT")
                Text("Inspiriert von Hex für macOS (Kit Langton). Die Transkription läuft vollständig lokal auf dem Gerät — keine Cloud, kein Account.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Einstellungen")
        .onAppear { model.refreshDownloadedModels() }
        .onChange(of: autoCopy) { SharedSettings.autoCopy = autoCopy }
        .onChange(of: autoInsert) { SharedSettings.autoInsert = autoInsert }
        .onChange(of: soundEffects) { SharedSettings.soundEffects = soundEffects }
        .onChange(of: haptics) { SharedSettings.haptics = haptics }
        .onChange(of: minDuration) { SharedSettings.minDuration = minDuration }
        .onChange(of: maxMinutes) { SharedSettings.maxMinutes = maxMinutes }
        .onChange(of: readyIndicator) { model.setReadyIndicator(readyIndicator) }
    }
}

private struct ModelRow: View {
    let hexModel: HexModel
    let isSelected: Bool
    let isDownloaded: Bool
    let progress: Double?
    let select: () -> Void
    let download: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(hexModel.displayName)
                    .font(.headline)
                Text(hexModel.badge)
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(.white)
                Spacer()
                trailingState
            }

            HStack(spacing: 16) {
                DotsView(filled: hexModel.accuracyDots, label: "Genauigkeit")
                DotsView(filled: hexModel.speedDots, label: "Tempo")
                Spacer()
                Text(hexModel.sizeLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(hexModel.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .contextMenu {
            if isDownloaded {
                Button(role: .destructive, action: delete) {
                    Label("Modell löschen", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var trailingState: some View {
        if let progress {
            Text(progress, format: .percent.precision(.fractionLength(0)))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        } else if isDownloaded {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Button(action: download) {
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct DotsView: View {
    let filled: Int
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 5, id: \.self) { index in
                Circle()
                    .fill(index < filled ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
