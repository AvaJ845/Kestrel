import Foundation
import UserNotifications
import Observation

/// Requests notification permission and posts honest "movement" alerts when a
/// watched station breaks its rhythm past the user's chosen sensitivity.
/// A cooldown prevents repeat pings for the same station.
@MainActor
@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    enum Status { case notDetermined, denied, authorized }
    private(set) var status: Status = .notDetermined

    private let center = UNUserNotificationCenter.current()
    private let defaults: UserDefaults
    private let lastKey = "kestrel.alertLastFired"
    private let cooldown: TimeInterval = 6 * 3600

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        center.delegate = self
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: status = .authorized
        case .denied: status = .denied
        default: status = .notDetermined
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        await refreshStatus()
        return granted
    }

    /// Post notifications for any alert-enabled station that is currently past
    /// its sensitivity threshold and off cooldown.
    func evaluate(anomalies: [Anomaly], alerts: AlertStore, fahrenheit: Bool) async {
        guard status == .authorized else { return }
        var fired = defaults.dictionary(forKey: lastKey) as? [String: Double] ?? [:]
        let now = Date().timeIntervalSince1970

        for anomaly in anomalies {
            guard let sensitivity = alerts.sensitivity(anomaly.station.icao),
                  anomaly.tier >= sensitivity.minTier else { continue }
            if let last = fired[anomaly.station.icao], now - last < cooldown { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(anomaly.station.city): \(AnomalyPhrasing.rowQualifier(for: anomaly))"
            let temp = TempFormat.string(anomaly.currentTempC, fahrenheit: fahrenheit, decimals: 0)
            let z = anomaly.z.map { String(format: "%+.1fσ", $0) } ?? ""
            content.body = "Now \(temp) \(z) from its recent rhythm. An observation — not a forecast."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "kestrel.alert.\(anomaly.station.icao).\(Int(now))",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            try? await center.add(request)
            fired[anomaly.station.icao] = now
        }
        defaults.set(fired, forKey: lastKey)
    }

    // Show alerts even when Kestrel is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
