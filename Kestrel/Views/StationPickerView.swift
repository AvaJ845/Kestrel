import SwiftUI

/// Choose which stations Kestrel watches. Only watched stations are polled.
/// Free users are capped; hitting the cap opens the paywall.
struct StationPickerView: View {
    @Bindable var store: RadarStore
    @Bindable var entitlements: EntitlementStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var showPaywall = false

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
                if !entitlements.isPro {
                    Section {
                        HStack {
                            Label("\(store.watched.count) of \(FreeTierLimits.maxStations) stations",
                                  systemImage: "dot.radiowaves.left.and.right")
                            Spacer()
                            Button("Get Pro") { showPaywall = true }
                                .font(.caption.weight(.bold))
                        }
                    }
                }
                Section {
                    ForEach(filtered) { station in
                        Button { toggle(station) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(station.city).foregroundStyle(.primary)
                                    Text(station.icao).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.isWatching(station.icao) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
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
            .sheet(isPresented: $showPaywall) {
                PaywallView(entitlements: entitlements, reason: gateReason)
            }
        }
    }

    private var gateReason: String {
        "Free watches up to \(FreeTierLimits.maxStations) stations. Kestrel Pro removes the limit."
    }

    private func toggle(_ station: Station) {
        let ok = store.toggleWatch(station.icao)
        if !ok { showPaywall = true }
    }
}
