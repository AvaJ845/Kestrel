import SwiftUI

/// Choose which stations Kestrel watches. Only watched stations are polled.
struct StationPickerView: View {
    @Bindable var store: RadarStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [Station] {
        guard !query.isEmpty else { return StationCatalog.all }
        return StationCatalog.all.filter {
            $0.city.localizedCaseInsensitiveContains(query)
            || $0.icao.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filtered) { station in
                        Button { store.toggleWatch(station.icao) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(station.city)
                                        .foregroundStyle(.primary)
                                    Text(station.icao)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.isWatching(station.icao) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .accessibilityAddTraits(store.isWatching(station.icao) ? [.isSelected] : [])
                    }
                } footer: {
                    Text("Kestrel only fetches weather for the stations you watch. "
                         + "Nothing else leaves your device.")
                }
            }
            .searchable(text: $query, prompt: "Search cities")
            .navigationTitle("Stations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                        Task { await store.refresh() }
                    }
                }
            }
        }
    }
}
