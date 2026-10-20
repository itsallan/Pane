@preconcurrency import VLCKit

enum EngineEvent: Sendable {
    case stateChanged(VLCMediaPlayerState)
    case bufferingChanged(Double)
    case rateChanged(Double)
    case lengthChanged(Duration)
    case timeChanged
    case tracksChanged
    case chaptersChanged
    case capabilitiesChanged
    case frameStepped
    case frameCaptured
}
