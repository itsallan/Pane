import CoreGraphics

public enum Metrics {
    public static let edgeInset: CGFloat = 16
    public static let controlSpacing: CGFloat = 8
    /// Below Apple's 44 pt minimum hit target, nothing in the player gets smaller.
    public static let minimumHitTarget: CGFloat = 44
    public static let capsuleMaxWidth: CGFloat = 720
}
