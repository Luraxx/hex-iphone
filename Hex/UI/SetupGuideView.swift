import SwiftUI
import UIKit

struct SetupGuideView: View {
    var body: some View {
        List {
            Section("Action Button (empfohlen)") {
                Step(number: 1, text: "iOS-Einstellungen öffnen → „Action Button“.")
                Step(number: 2, text: "Zum Feld „Kurzbefehl“ wischen.")
                Step(number: 3, text: "„Kurzbefehl auswählen“ → unter Hex den Befehl „Diktat“ wählen.")
                Text("Danach gilt überall: Action Button drücken → sprechen → nochmal drücken. Der Status erscheint in der Dynamic Island.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Alternative: Doppel-Tipp auf die Rückseite") {
                Step(number: 1, text: "Einstellungen → Bedienungshilfen → Tippen → „Auf Rückseite tippen“.")
                Step(number: 2, text: "„Doppeltippen“ → Kurzbefehl „Diktat“ wählen.")
            }

            Section("Hex-Tastatur (automatisches Einfügen)") {
                Step(number: 1, text: "Einstellungen → Allgemein → Tastatur → Tastaturen → „Neue Tastatur hinzufügen“ → Hex Tastatur.")
                Step(number: 2, text: "Auf „Hex Tastatur“ tippen und „Vollzugriff erlauben“ aktivieren.")
                Text("Vollzugriff braucht die Tastatur nur, um das Transkript aus dem gemeinsamen App-Speicher zu lesen. Hex sendet nichts ins Netz.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Hex-Einstellungen in iOS öffnen", systemImage: "gear")
                }
            }

            Section("So diktierst du") {
                Step(number: 1, text: "In einer beliebigen App ins Textfeld tippen und mit dem Globus-Symbol zur Hex-Tastatur wechseln.")
                Step(number: 2, text: "Action Button drücken und sprechen.")
                Step(number: 3, text: "Action Button erneut drücken — der Text wird lokal transkribiert, kopiert und von der Hex-Tastatur automatisch eingefügt.")
                Text("Ohne Hex-Tastatur landet der Text in der Zwischenablage: einfach lange tippen → „Einfügen“.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Einrichtung")
    }
}

private struct Step: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.footnote.bold())
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.callout)
        }
    }
}
