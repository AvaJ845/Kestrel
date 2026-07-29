import SwiftUI
import UIKit

/// Manages the app's alternate icons. Three tasteful looks; the choice is a
/// pure convenience, available to everyone.
@MainActor
@Observable
final class IconManager {
    enum AppIcon: String, CaseIterable, Identifiable {
        case classic = "Classic"
        case midnight = "Midnight"
        case mono = "Mono"

        var id: String { rawValue }

        /// nil = primary icon (Classic); otherwise the alternate icon name.
        var alternateName: String? {
            switch self {
            case .classic: return nil
            case .midnight: return "AppIcon-Midnight"
            case .mono: return "AppIcon-Mono"
            }
        }

        var subtitle: String {
            switch self {
            case .classic: return "Warm dusk"
            case .midnight: return "Deep blue night"
            case .mono: return "Charcoal monochrome"
            }
        }

        /// Gradient + trace colors so the picker can draw a faithful
        /// thumbnail in SwiftUI (no bundled preview PNGs required).
        var gradientColors: [Color] {
            switch self {
            case .classic:
                return [Color(red: 0.96, green: 0.66, blue: 0.31),
                        Color(red: 0.93, green: 0.48, blue: 0.22),
                        Color(red: 0.05, green: 0.16, blue: 0.18)]
            case .midnight:
                return [Color(red: 0.23, green: 0.38, blue: 0.66),
                        Color(red: 0.14, green: 0.24, blue: 0.47),
                        Color(red: 0.03, green: 0.05, blue: 0.12)]
            case .mono:
                return [Color(red: 0.47, green: 0.49, blue: 0.51),
                        Color(red: 0.31, green: 0.32, blue: 0.34),
                        Color(red: 0.08, green: 0.08, blue: 0.09)]
            }
        }

        var traceColor: Color {
            switch self {
            case .classic: return Color(red: 1.0, green: 0.96, blue: 0.92)
            case .midnight: return Color(red: 0.88, green: 0.93, blue: 1.0)
            case .mono: return Color(red: 0.96, green: 0.96, blue: 0.97)
            }
        }
    }

    private(set) var current: AppIcon
    var supportsAlternateIcons: Bool { UIApplication.shared.supportsAlternateIcons }

    init() {
        let name = UIApplication.shared.alternateIconName
        current = AppIcon.allCases.first { $0.alternateName == name } ?? .classic
    }

    func select(_ icon: AppIcon) {
        guard icon != current else { return }
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(icon.alternateName) { [weak self] error in
            Task { @MainActor in
                if error == nil { self?.current = icon }
                else { self?.current = AppIcon.allCases.first {
                    $0.alternateName == UIApplication.shared.alternateIconName } ?? .classic }
            }
        }
    }
}
