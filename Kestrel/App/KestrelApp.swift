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
    }

    var body: some Scene {
        WindowGroup {
            RadarView(store: store, entitlements: entitlements, iconManager: iconManager)
                .task {
                    await entitlements.loadProducts()
                    await notifications.refreshStatus()
                }
        }
    }
}
