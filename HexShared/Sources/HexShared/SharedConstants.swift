import Foundation

/// Identifiers shared between the app and the keyboard extension.
public enum SharedConstants {
    /// App Group for the shared data container (app <-> keyboard).
    public static let appGroupID = "group.io.github.luraxx.hex"

    /// The app's URL scheme (e.g. hex://toggle, used by the keyboard).
    public static let urlScheme = "hex"

    /// Darwin notifications (cross-process, payload-free).
    public enum Darwin {
        /// A new transcript was saved (the keyboard can insert it immediately).
        public static let newTranscript = "io.github.luraxx.hex.darwin.newTranscript"
        /// Recording state changed (keyboard UI refresh).
        public static let recordingStateChanged = "io.github.luraxx.hex.darwin.recordingState"
    }
}
