import AudioToolbox
import HexShared
import UIKit

/// Acoustic + haptic feedback. Uses the system recording sounds
/// (the same ones as Voice Memos), so nothing needs to be bundled.
enum Feedback {
    private static let beginRecordSound: SystemSoundID = 1113
    private static let endRecordSound: SystemSoundID = 1114

    static func recordStart() {
        if SharedSettings.soundEffects { AudioServicesPlaySystemSound(beginRecordSound) }
        impact(.medium)
    }

    static func recordStop() {
        if SharedSettings.soundEffects { AudioServicesPlaySystemSound(endRecordSound) }
        impact(.medium)
    }

    static func done() {
        impact(.light)
    }

    static func error() {
        if SharedSettings.haptics {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard SharedSettings.haptics else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
