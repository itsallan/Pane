import DesignSystem
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Applies the theme from Settings to the whole app. Set on the platform rather than with `preferredColorScheme`,
/// which doesn't go back to following the system when it's set to `nil` again.
private struct AppearanceSync: ViewModifier {
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system

    func body(content: Content) -> some View {
        content.onChange(of: appearance, initial: true) { _, appearance in
            apply(appearance)
        }
    }

    private func apply(_ appearance: AppAppearance) {
        #if os(iOS)
        let style: UIUserInterfaceStyle = switch appearance {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
        #else
        NSApp.appearance = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
        #endif
    }
}

extension View {
    func syncsAppearance() -> some View {
        modifier(AppearanceSync())
    }
}
