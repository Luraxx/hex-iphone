import AVFoundation
import HexShared
import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    @State private var page = 0
    @State private var micGranted = AVAudioApplication.shared.recordPermission == .granted

    var body: some View {
        TabView(selection: $page) {
            welcome.tag(0)
            microphone.tag(1)
            modelDownload.tag(2)
            setup.tag(3)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .interactiveDismissDisabled()
    }

    private var welcome: some View {
        OnboardingPage(
            symbol: "hexagon",
            title: "Willkommen bei Hex",
            text: "Diktieren wie am Mac: Action Button drücken, sprechen, fertig. Die Umwandlung in Text passiert mit den Parakeet-Modellen komplett lokal auf deinem iPhone."
        ) {
            Button("Weiter") { page = 1 }
                .buttonStyle(.borderedProminent)
        }
    }

    private var microphone: some View {
        OnboardingPage(
            symbol: "mic.fill",
            title: "Mikrofon",
            text: "Hex braucht Zugriff auf das Mikrofon. Deine Aufnahmen verlassen das Gerät nie."
        ) {
            if micGranted {
                Label("Erlaubt", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Weiter") { page = 2 }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Mikrofon erlauben") {
                    Task {
                        micGranted = await AVAudioApplication.requestRecordPermission()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var modelDownload: some View {
        OnboardingPage(
            symbol: "arrow.down.circle",
            title: "Modell laden",
            text: "Parakeet TDT v3 (multilingual, inkl. Deutsch) ist rund 650 MB groß — am besten im WLAN laden. Der Download läuft im Hintergrund weiter."
        ) {
            if model.downloadedModels.contains(.multilingualV3) {
                Label("Geladen", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if let progress = model.downloadProgress[.multilingualV3] {
                ProgressView(value: progress)
                    .frame(maxWidth: 220)
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Button("Parakeet v3 laden (650 MB)") {
                    model.downloadModel(.multilingualV3)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Weiter") { page = 3 }
                .buttonStyle(.bordered)
        }
    }

    private var setup: some View {
        OnboardingPage(
            symbol: "wand.and.stars",
            title: "Fast fertig",
            text: "Zwei Dinge in den iOS-Einstellungen:\n\n1. Action Button: Einstellungen → Action Button → „Kurzbefehl“ → Hex „Diktat“.\n\n2. Tastatur: Einstellungen → Allgemein → Tastatur → Tastaturen → „Hex Tastatur“ hinzufügen und Vollzugriff erlauben — dann fügt Hex den Text automatisch ins aktive Feld ein."
        ) {
            Button("Los geht’s") {
                SharedSettings.didOnboard = true
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct OnboardingPage<Actions: View>: View {
    let symbol: String
    let title: String
    let text: String
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.title.bold())
            Text(text)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)
            actions
            Spacer()
            Spacer()
        }
        .padding()
    }
}
