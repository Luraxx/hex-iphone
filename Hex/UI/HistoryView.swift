import HexShared
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [Transcript] = []
    @State private var query = ""

    private var filtered: [Transcript] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            ForEach(filtered) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.text)
                        .font(.callout)
                        .lineLimit(6)
                    HStack(spacing: 6) {
                        Text(item.createdAt, format: .dateTime.day().month().hour().minute())
                        Text("·")
                        Text(Duration.seconds(item.duration), format: .time(pattern: .minuteSecond))
                        Text("·")
                        Text(item.modelID.contains("-v2-") ? "v2" : "v3")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = item.text
                    } label: {
                        Label("Kopieren", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: item.text)
                    Button(role: .destructive) {
                        model.store.delete(id: item.id)
                        reload()
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        model.store.delete(id: item.id)
                        reload()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView(
                    "Noch keine Transkripte",
                    systemImage: "text.bubble",
                    description: Text("Halte den Action Button gedrückt und sprich los.")
                )
            }
        }
        .searchable(text: $query, prompt: "Durchsuchen")
        .navigationTitle("Verlauf")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        model.store.deleteAll()
                        reload()
                    } label: {
                        Label("Alle löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        items = model.store.all()
    }
}
