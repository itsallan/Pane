/// Forces the interface orientation, injected by the app target on iPhone so the feature never touches UIKit.
@MainActor
public protocol ScreenOrientation: AnyObject {
    /// Turns the interface to the other orientation and holds it there until `unlock()`, whichever way the phone is held.
    func rotate()
    func unlock()
}
