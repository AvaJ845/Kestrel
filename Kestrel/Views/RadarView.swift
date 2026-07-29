import SwiftUI

/// The home surface: a ranked radar of watched stations, strongest anomaly
/// first. Honest framing lives at the top and bottom of the list.
struct RadarView: View {
    @Bindable var store: RadarStore
    @State private var showStations = false
    @State private var showAbout = false
    @State private var selection: Anomaly?

    var body: some View {
        NavigationStack {
            Group {
                if store.anomalies.isEmpty && store.isLoading {
                    LoadingState()
                } else if store.watchedStations.isEmpty {
                    EmptyRadarState { showStations = true }
                } else {
                    radarList
                }
            }
            .navigationTitle("Kestrel")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { store.useFahrenheit.toggle() } label: {
                        Text(store.useFahrenheit ? "°F" : "°C")
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                    }
                    .accessibilityLabel(store.useFahrenheit
                        ? "Showing Fahrenheit. Switch to Celsius."
                        : "Showing Celsius. Switch to Fahrenheit.")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showAbout = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("About Kestrel")
                    Button { showStations = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Choose stations")
                }
            }
            .sheet(isPresented: $showStations) {
                StationPickerView(store: store)
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .navigationDestination(item: $selection) { anomaly in
                AnomalyDetailView(anomaly: anomaly, fahrenheit: store.useFahrenheit)
            }
        }
        .task { await store.refresh() }
    }

    private var radarList: some View {
        List {
            Section {
                ForEach(store.anomalies) { anomaly in
                    Button { selection = anomaly } label: {
                        AnomalyRow(anomaly: anomaly, fahrenheit: store.useFahrenheit)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            } header: {
                RadarHeader(lastUpdated: store.lastUpdated)
                    .textCase(nil)
            } footer: {
                Text(AppText.disclaimerShort)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await store.refresh() }
        .overlay(alignment: .bottom) {
            if let error = store.errorMessage {
                ErrorBanner(message: error)
                    .padding()
            }
        }
    }
}

private struct RadarHeader: View {
    let lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppText.tagline)
                .font(.headline)
                .foregroundStyle(.primary)
            if let lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.red.opacity(0.9), in: Capsule())
            .shadow(radius: 6, y: 3)
    }
}
