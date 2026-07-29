import SwiftUI

struct SettingsView: View {
    @Bindable var entitlements: EntitlementStore
    @Bindable var store: RadarStore
    @Bindable var iconManager: IconManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                baselineSection
                alertsSection
                subscriptionSection
                aboutSection
                #if DEBUG
                developerSection
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(entitlements: entitlements)
            }
            .task { await store.notifications.refreshStatus() }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Toggle("Show Fahrenheit", isOn: $store.useFahrenheit)

            if iconManager.supportsAlternateIcons {
                ForEach(IconManager.AppIcon.allCases) { icon in
                    Button { withAnimation(.snappy) { iconManager.select(icon) } } label: {
                        HStack(spacing: 14) {
                            IconThumb(icon: icon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(icon.rawValue) icon").foregroundStyle(.primary)
                                Text(icon.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if iconManager.current == icon {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                            }
                        }
                    }
                    .accessibilityAddTraits(iconManager.current == icon ? [.isSelected] : [])
                }
            }
        }
    }

    // MARK: Baseline

    private var baselineSection: some View {
        Section {
            if entitlements.isPro {
                Picker("Baseline window", selection: $store.baselineDays) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                }
                .onChange(of: store.baselineDays) { _, _ in
                    Task { await store.refresh() }
                }
            } else {
                HStack {
                    Text("Baseline window")
                    Spacer()
                    Text("7 days").foregroundStyle(.secondary)
                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                }
                Button { showPaywall = true } label: {
                    Label("Extend to 14 or 30 days with Pro", systemImage: "sparkles")
                }
            }
        } header: {
            Text("Baseline")
        } footer: {
            Text("How much same-hour history each anomaly is measured against. A longer window is steadier and less jumpy; a shorter one reacts faster. Free uses 7 days.")
        }
    }

    // MARK: Alerts

    private var alertsSection: some View {
        Section {
            switch store.notifications.status {
            case .authorized:
                Label("Notifications on", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.tint)
            case .denied:
                Label("Notifications are off in iOS Settings", systemImage: "bell.slash")
                    .foregroundStyle(.secondary)
            case .notDetermined:
                Button {
                    Task { await store.notifications.requestAuthorization() }
                } label: {
                    Label("Turn on spike alerts", systemImage: "bell.badge")
                }
            }

            if store.alerts.enabledCount == 0 {
                Text("Long-press any station on the radar to set a spike alert.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(sortedAlerts) { entry in
                    HStack {
                        Text(entry.city)
                        Spacer()
                        Text(entry.sensitivity.label).font(.caption).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) { store.alerts.disable(entry.id) } label: {
                            Label("Off", systemImage: "bell.slash")
                        }
                    }
                }
            }
        } header: {
            Text("Spike alerts")
        } footer: {
            Text("An honest movement alert — Kestrel pings you when a station is unusually far from its rhythm. It's an observation, never a forecast or a call to act.")
        }
    }

    private var sortedAlerts: [AlertEntry] {
        store.alerts.configs.compactMap { icao, sens in
            guard let s = StationCatalog.station(icao: icao) else { return nil }
            return AlertEntry(id: icao, city: s.city, sensitivity: sens)
        }.sorted { $0.city < $1.city }
    }

    // MARK: Subscription

    private var subscriptionSection: some View {
        Section("Subscription") {
            if entitlements.isPro {
                Label("Kestrel Pro is active", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.tint)
            } else {
                Button { showPaywall = true } label: {
                    Label("Upgrade to Kestrel Pro", systemImage: "sparkles")
                }
            }
            Button("Restore Purchases") { Task { await entitlements.restore() } }
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            Link("Privacy Policy", destination: AppLegal.privacyURL)
            Link("Terms of Use", destination: AppLegal.termsURL)
        } footer: {
            Text(AppText.disclaimerShort)
        }
    }

    #if DEBUG
    private var developerSection: some View {
        Section {
            Toggle("Unlock Pro (QA)", isOn: $entitlements.debugUnlocked)
        } header: {
            Text("Developer")
        } footer: {
            Text("Testing only — this switch is compiled out of the App Store build.")
        }
    }
    #endif
}

/// One enabled spike-alert, keyed by ICAO for `ForEach`.
struct AlertEntry: Identifiable {
    let id: String
    let city: String
    let sensitivity: AlertStore.Sensitivity
}

/// A faithful SwiftUI thumbnail of an app-icon variant (no bundled PNGs).
struct IconThumb: View {
    let icon: IconManager.AppIcon

    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(LinearGradient(colors: icon.gradientColors, startPoint: .top, endPoint: .bottom))
            .frame(width: 40, height: 40)
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width, h = geo.size.height
                    Path { p in
                        p.move(to: CGPoint(x: w * 0.14, y: h * 0.62))
                        p.addLine(to: CGPoint(x: w * 0.48, y: h * 0.60))
                        p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.30))
                        p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.60))
                        p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.60))
                    }
                    .stroke(icon.traceColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.12)))
            .accessibilityHidden(true)
    }
}
