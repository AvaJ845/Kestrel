import Foundation

/// Momentum (ASO): ask for a review only at a *happy moment* — after the user
/// has seen the radar work a few times — and at most once per app version.
/// Never at launch, never after an error.
enum ReviewPrompt {
    private static let countKey = "kestrel.successCount"
    private static let promptedVersionKey = "kestrel.reviewPromptedVersion"

    static func registerSuccessAndShouldRequest(defaults: UserDefaults = .standard) -> Bool {
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        guard count >= 3, defaults.string(forKey: promptedVersionKey) != version else { return false }
        defaults.set(version, forKey: promptedVersionKey)
        return true
    }
}
