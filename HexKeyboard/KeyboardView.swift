import HexShared
import SwiftUI

@Observable
final class KeyboardState {
    var recent: [Transcript] = []
    var hasFullAccess = false
    var storeAvailable = false
    var needsInputModeSwitchKey = true
    var insertedFlash = false

    func flashInserted() {
        insertedFlash = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            self.insertedFlash = false
        }
    }
}

struct KeyboardView: View {
    let state: KeyboardState
    let insertText: (String) -> Void
    let deleteBackward: () -> Void
    let insertNewline: () -> Void
    let insertSpace: () -> Void
    let switchKeyboard: () -> Void
    let openApp: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            statusRow
            transcriptArea
            recentRow
            controlRow
        }
        .padding(10)
    }

    // MARK: - Rows

    private var statusRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "hexagon")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
            Text("Hex")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if state.insertedFlash {
                Label("Eingefügt", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Text("Action Button: aufnehmen / stoppen")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var transcriptArea: some View {
        if !state.hasFullAccess || !state.storeAvailable {
            Button(action: openApp) {
                VStack(spacing: 4) {
                    Label("Vollzugriff aktivieren", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                    Text("Einstellungen → Allgemein → Tastatur → Hex Tastatur → Vollzugriff erlauben")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(10)
                .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        } else if let latest = state.recent.first {
            Button {
                insertText(latest.text)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "text.insert")
                        .foregroundStyle(Color.accentColor)
                    Text(latest.text)
                        .font(.footnote)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(latest.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        } else {
            VStack(spacing: 4) {
                Text("Noch kein Transkript")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Drücke den Action Button und sprich los.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var recentRow: some View {
        if state.recent.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(state.recent.dropFirst()) { item in
                        Button {
                            insertText(item.text)
                        } label: {
                            Text(item.text)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(maxWidth: 170, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(.secondarySystemBackground), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var controlRow: some View {
        HStack(spacing: 6) {
            if state.needsInputModeSwitchKey {
                KeyButton(systemImage: "globe", action: switchKeyboard)
            }
            KeyButton(systemImage: "hexagon.fill", action: openApp)
            Button(action: insertSpace) {
                Text("Leerzeichen")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            KeyButton(systemImage: "delete.left", action: deleteBackward)
            KeyButton(systemImage: "return", action: insertNewline)
        }
    }
}

private struct KeyButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 42)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
