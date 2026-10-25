import CoreGraphics

public enum Metrics {
    public static let edgeInset: CGFloat = 16
    public static let controlSpacing: CGFloat = 8
    /// Below Apple's 44 pt minimum hit target, nothing in the player gets smaller.
    public static let minimumHitTarget: CGFloat = 44
    public static let capsuleMaxWidth: CGFloat = 720
    /// iPhone landscape, where the video wants every point the chrome can give back.
    public static let compactEdgeInset: CGFloat = 8
    public static let panelCornerRadius: CGFloat = 28
    public static let panelPadding: CGFloat = 20
    public static let capsulePadding: CGFloat = 6
    public static let railSpacing: CGFloat = 2
    public static let centerPlaySize: CGFloat = 76
    public static let centerSkipSize: CGFloat = 56
    public static let centerSpacing: CGFloat = 28
    public static let statusMaxWidth: CGFloat = 340
    public static let statusSpinnerSize: CGFloat = 72
    public static let optionsPopoverWidth: CGFloat = 360
    public static let optionsPopoverHeight: CGFloat = 520
    /// Wide enough that "0.75x" and "-00:00" never truncate next to a slider.
    public static let valueLabelMinWidth: CGFloat = 52
    /// How close glass shapes get before they start to blend.
    public static let glassMergeSpacing: CGFloat = 24
}

extension Metrics {
    public static let posterAspectRatio: CGFloat = 16 / 9
    public static let posterCornerRadius: CGFloat = 12
    /// Two columns on an iPhone, four or more on an iPad.
    public static let posterMinimumWidth: CGFloat = 156
    public static let posterRegularMinimumWidth: CGFloat = 220
    public static let progressBarHeight: CGFloat = 4
    public static let gridSpacing: CGFloat = 16
    public static let sectionSpacing: CGFloat = 28
    public static let sectionHeaderSpacing: CGFloat = 10
    public static let heroCornerRadius: CGFloat = 20
    /// The share of the width a Continue Watching card takes, so the next one peeks in.
    public static let heroWidthFraction: CGFloat = 0.86
    public static let heroMaximumWidth: CGFloat = 520
    public static let badgeSize: CGFloat = 36
    public static let iconTileSize: CGFloat = 30
    public static let iconTileCornerRadius: CGFloat = 7
}
