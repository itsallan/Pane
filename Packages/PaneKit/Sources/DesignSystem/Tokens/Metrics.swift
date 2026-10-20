import CoreGraphics

public enum Metrics {
    public static let edgeInset: CGFloat = 16
    public static let controlSpacing: CGFloat = 8
    /// Below Apple's 44 pt minimum hit target, nothing in the player gets smaller.
    public static let minimumHitTarget: CGFloat = 44
    public static let capsuleMaxWidth: CGFloat = 720
}

extension Metrics {
    public static let posterAspectRatio: CGFloat = 16 / 9
    public static let posterCornerRadius: CGFloat = 12
    public static let posterMinimumWidth: CGFloat = 200
    public static let continueWatchingWidth: CGFloat = 280
    public static let rowPosterWidth: CGFloat = 120
    public static let progressBarHeight: CGFloat = 4
}
