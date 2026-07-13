import Foundation

/// Settings in the shared UserDefaults suite (app + keyboard).
public enum SharedSettings {
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedConstants.appGroupID) ?? .standard
    }

    private enum Key {
        static let selectedModelID = "selectedModelID"
        static let autoCopy = "autoCopy"
        static let autoInsert = "autoInsert"
        static let soundEffects = "soundEffects"
        static let haptics = "haptics"
        static let minDuration = "minDuration"
        static let maxMinutes = "maxMinutes"
        static let didOnboard = "didOnboard"
    }

    private static func bool(_ key: String, default defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    /// Selected transcription model (default: Parakeet TDT v3, multilingual).
    public static var selectedModelID: String {
        get { defaults.string(forKey: Key.selectedModelID) ?? "parakeet-tdt-0.6b-v3-coreml" }
        set { defaults.set(newValue, forKey: Key.selectedModelID) }
    }

    /// Automatically copy transcripts to the clipboard.
    public static var autoCopy: Bool {
        get { bool(Key.autoCopy, default: true) }
        set { defaults.set(newValue, forKey: Key.autoCopy) }
    }

    /// The Hex keyboard auto-inserts the latest transcript.
    public static var autoInsert: Bool {
        get { bool(Key.autoInsert, default: true) }
        set { defaults.set(newValue, forKey: Key.autoInsert) }
    }

    public static var soundEffects: Bool {
        get { bool(Key.soundEffects, default: true) }
        set { defaults.set(newValue, forKey: Key.soundEffects) }
    }

    public static var haptics: Bool {
        get { bool(Key.haptics, default: true) }
        set { defaults.set(newValue, forKey: Key.haptics) }
    }

    /// Recordings shorter than this (seconds) are discarded.
    public static var minDuration: Double {
        get { defaults.object(forKey: Key.minDuration) == nil ? 0.3 : defaults.double(forKey: Key.minDuration) }
        set { defaults.set(newValue, forKey: Key.minDuration) }
    }

    /// Maximum recording duration in minutes (safety net against forgotten recordings).
    public static var maxMinutes: Int {
        get { defaults.object(forKey: Key.maxMinutes) == nil ? 10 : defaults.integer(forKey: Key.maxMinutes) }
        set { defaults.set(newValue, forKey: Key.maxMinutes) }
    }

    public static var didOnboard: Bool {
        get { bool(Key.didOnboard, default: false) }
        set { defaults.set(newValue, forKey: Key.didOnboard) }
    }
}
