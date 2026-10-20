/// The display's brightness, injected by the app target so the feature never touches UIScreen.
@MainActor
public protocol ScreenBrightness: AnyObject {
    /// `0...1`.
    var level: Double { get set }
}
