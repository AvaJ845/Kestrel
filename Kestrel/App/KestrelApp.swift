import SwiftUI

@main
struct KestrelApp: App {
    @State private var entitlements: EntitlementStore
    @State private var iconManager = IconManager()
    @State private var store: RadarStore
    private let notifications: NotificationManager

    init() {
        let ent = EntitlementStore()
        let alerts = AlertStore()
        let notifs = NotificationManager()
        _entitlements = State(initialValue: ent)
        _store = State(initialValue: RadarStore(entitlements: ent,
                                                alerts: alerts,
                                                notifications: notifs))
        notifications = notifs
        #if DEBUG
        if ProcessInfo.processInfo.environment["KESTREL_PRO"] == "1" { ent.debugUnlocked = true }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let screen = ProcessInfo.processInfo.environment["KESTREL_SHOT"],
               ["detail", "settings", "about"].contains(screen) {
                screenshotRoot(screen)
            } else {
                mainView
            }
            #else
            mainView
            #endif
        }
    }

    private var mainView: some View {
        RadarView(store: store, entitlements: entitlements, iconManager: iconManager)
            .task {
                await entitlements.loadProducts()
                await notifications.refreshStatus()
            }
    }

    #if DEBUG
    @ViewBuilder
    private func screenshotRoot(_ screen: String) -> some View {
        switch screen {
        case "detail":
            NavigationStack {
                AnomalyDetailView(anomaly: .sampleDenver, fahrenheit: false,
                                  isPro: true, store: store)
            }
        case "settings":
            SettingsView(entitlements: entitlements, store: store, iconManager: iconManager)
        case "about":
            AboutView()
        default:
            mainView
        }
    }
    #endif
}
