import SwiftUI

extension Animation {
    public static let chrome = Animation.smooth(duration: 0.35)
    /// Long enough that a scene cut reads as light changing, not a flash.
    public static let ambientFade = Animation.easeInOut(duration: 1.4)
    public static let quickFade = Animation.smooth(duration: 0.2)

    /// Reduce Motion keeps the timing but drops movement, which callers do by swapping transitions for opacity.
    public static func chrome(reduceMotion: Bool) -> Animation {
        reduceMotion ? .linear(duration: 0.15) : .chrome
    }
}
