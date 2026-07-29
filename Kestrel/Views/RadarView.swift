import SwiftUI

/// The home surface: a hero summary + a ranked radar of watched stations,
/// strongest anomaly first. Honest framing top and bottom.
struct RadarView: View {
    @Bindable var store: RadarStore
    @Bindable var entitlements: EntitlementStore
    @Bindable var iconManager: IconManager
    @State private var showStations = false
    @State private var showAbout = false
    @State private var showSettings = false
    @State private var selection: Anomaly?
    @AppStorage("kestrel.onboarded") private var onboarded = false

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
            .toolbar { toolbarContent }
            .sheet(isPresented: $showStations) {
                StationPickerView(store: store, entitlements: entitlements)
            }
            .sheet(isPresented: $showAbout) { AboutView() }
            .sheet(isPresented: $showSettings) {
                SettingsView(entitlements: entitlements, store: store, iconManager: iconManager)
            }
            .sheet(item: paywallBinding) { _ in
                PaywallView(entitlements: entitlements, reason: store.paywallReason)
            }
            .navigationDestination(item: $selection) { anomaly in
                AnomalyDetailView(anomaly: anomaly, fahrenheit: store.useFahrenheit,
                                  isPro: entitlements.isPro, store: store)
            }
        }
        .task { await store.refresh() }
        .onChange(of: entitlements.isPro) { _, _ in
            Task { await store.refresh() }
        }
        .fullScreenCover(isPresented: .init(get: { !onboarded }, set: { if !$0 { onboarded = true } })) {
            OnboardingView { onboarded = true }
        }
    }

    private var paywallBinding: Binding<PaywallToken?> {
        Binding(
            get: { store.paywallReason.map(PaywallToken.init) },
            set: { if $0 == nil { store.paywallReason = nil } }
        )
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { store.useFahrenheit.toggle() } label: {
                Text(store.useFahrenheit ? "°F" : "°C")
                    .font(.subheadline.weight(.bold)).monospacedDigit()
            }
            .accessibilityLabel(store.useFahrenheit ? "Showing Fahrenheit" : "Showing Celsius")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !entitlements.isPro {
                Button { store.paywallReason = "Unlock unlimited stations and a steadier 30-day baseline." } label: {
                    Text("Pro").font(.caption.weight(.bold))
                }
                .accessibilityLabel("Kestrel Pro")
            }
            Button { showStations = true } label: {
                Image(systemName: store.watchedStations.isEmpty ? "star" : "star.fill")
            }
            .accessibilityLabel("Favorite stations")
            Menu {
                Button { showAbout = true } label: { Label("About Kestrel", systemImage: "info.circle") }
                Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More")
        }
    }

    private var radarList: some View {
        List {
            Section {
                HeroSummary(breaking: store.summary.breaking,
                            total: store.summary.total,
                            lastUpdated: store.lastUpdated,
                            isPro: entitlements.isPro)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }

            Section {
                ForEach(store.anomalies) { anomaly in
                    Button { selection = anomaly } label: {
                        AnomalyRow(anomaly: anomaly,
                                   fahrenheit: store.useFahrenheit,
                                   alertEnabled: store.alerts.isEnabled(anomaly.station.icao))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .contextMenu { StationContextMenu(store: store, anomaly: anomaly, isPro: entitlements.isPro) }
                }
            } footer: {
                Text(AppText.disclaimerShort)
                    .font(.footnote).foregroundStyle(.secondary).padding(.top, 8)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await store.refresh() }
        .animation(.snappy, value: store.anomalies)
        .overlay(alignment: .bottom) {
            if let error = store.errorMessage {
                ErrorBanner(message: error).padding()
            }
        }
    }
}

/// Long-press menu on a station: honest movement alerts + remove.
struct StationContextMenu: View {
    @Bindable var store: RadarStore
    let anomaly: Anomaly
    var isPro: Bool = false

    var body: some View {
        let icao = anomaly.station.icao
        Menu {
            menuRow("Off", selected: !store.alerts.isEnabled(icao)) {
                store.alerts.disable(icao)
            }
            ForEach(AlertStore.Sensitivity.allCases) { s in
                menuRow(s.label, selected: store.alerts.sensitivity(icao) == s) {
                    enableAlert(icao, sensitivity: s)
                }
            }
        } label: {
            Label("Spike alert", systemImage: store.alerts.isEnabled(icao) ? "bell.fill" : "bell")
        }

        Button(role: .destructive) {
            store.toggleWatch(icao)
        } label: {
            Label("Remove from radar", systemImage: "star.slash")
        }
    }

    @ViewBuilder
    private func menuRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if selected { Label(title, systemImage: "checkmark") } else { Text(title) }
        }
    }

    private func enableAlert(_ icao: String, sensitivity: AlertStore.Sensitivity) {
        let alreadyThis = store.alerts.isEnabled(icao)
        if !isPro, !alreadyThis, store.alerts.enabledCount >= FreeTierLimits.maxAlertsFree {
            store.paywallReason = "Free includes one spike alert. Kestrel Pro unlocks alerts on every station."
            return
        }
        store.alerts.setAlert(icao, sensitivity: sensitivity)
        Task {
            if store.notifications.status != .authorized {
                await store.notifications.requestAuthorization()
            }
        }
    }
}

/// Wraps the paywall reason string so it can drive `sheet(item:)`.
struct PaywallToken: Identifiable { let id: String; init(_ s: String) { id = s } }

/// Glanceable top-of-radar summary (HCI lens).
struct HeroSummary: View {
    let breaking: Int
    let total: Int
    let lastUpdated: Date?
    let isPro: Bool

    private var headline: String {
        guard total > 0 else { return "No stations scored yet" }
        if breaking == 0 { return "All \(total) stations within rhythm" }
        return "\(breaking) of \(total) breaking rhythm"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: breaking == 0 ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                    .foregroundStyle(breaking == 0 ? .green : .orange)
                Text(headline).font(.title3.weight(.bold))
            }
            Text(AppText.tagline)
                .font(.subheadline).foregroundStyle(.secondary)
            if let lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))"
                     + (isPro ? " · 30-day baseline" : " · 7-day baseline"))
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct ErrorBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline).foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.red.opacity(0.9), in: Capsule())
            .shadow(radius: 6, y: 3)
    }
}
