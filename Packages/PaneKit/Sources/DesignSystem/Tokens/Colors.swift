import SwiftUI

extension Color {
    /// Behind the video in both appearances, so letterboxing never shows the window color.
    public static let mediaBackground = Color.black
    public static let scrubberTrack = Color.primary.opacity(0.22)
    public static let scrubberFill = Color.primary
    public static let levelBoost = Color.orange
    /// Over the ambient wash, so white chrome stays legible on a bright frame.
    /// Marks the chosen item inside a glass capsule, where a tint would fight the colors coming through.
    public static let glassSelection = Color.white.opacity(0.22)
    public static let ambientScrim = Color.black.opacity(0.25)
}

extension ShapeStyle where Self == LinearGradient {
    /// Under text laid over artwork, so a bright frame never swallows the title.
    public static var artworkScrim: LinearGradient {
        LinearGradient(
            stops: [.init(color: .clear, location: 0.35), .init(color: .black.opacity(0.78), location: 1)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
