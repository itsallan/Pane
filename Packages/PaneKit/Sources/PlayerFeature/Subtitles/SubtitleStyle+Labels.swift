import Domain
import Foundation

extension SubtitleStyle.Size {
    var label: LocalizedStringResource {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    // Mirrors the text scale the engine gives libvlc, so the preview line matches what VLC draws.
    var previewScale: Double {
        switch self {
        case .small: 0.75
        case .medium: 1
        case .large: 1.3
        case .extraLarge: 1.6
        }
    }
}

extension SubtitleStyle.Background {
    var label: LocalizedStringResource {
        switch self {
        case .none: "None"
        case .translucent: "Translucent"
        case .solid: "Solid"
        }
    }
}

extension SubtitleStyle.Position {
    var label: LocalizedStringResource {
        switch self {
        case .bottom: "Bottom"
        case .raised: "Raised"
        case .high: "High"
        }
    }

    /// The margin the engine asks libvlc for, in pixels.
    var marginPixels: Double {
        switch self {
        case .bottom: 0
        case .raised: 80
        case .high: 200
        }
    }
}
