import FluidAudio
import Foundation

/// The supported Parakeet models — identical to Hex on the Mac.
enum HexModel: String, CaseIterable, Identifiable, Codable {
    case englishV2 = "parakeet-tdt-0.6b-v2-coreml"
    case multilingualV3 = "parakeet-tdt-0.6b-v3-coreml"

    var id: String { rawValue }
    var identifier: String { rawValue }

    static var selected: HexModel {
        HexModel(rawValue: HexSettingsBridge.selectedModelID) ?? .multilingualV3
    }

    var displayName: String {
        switch self {
        case .englishV2: "Parakeet TDT v2"
        case .multilingualV3: "Parakeet TDT v3"
        }
    }

    var badge: String {
        switch self {
        case .englishV2: "BEST FOR ENGLISH"
        case .multilingualV3: "BEST FOR MULTILINGUAL"
        }
    }

    var subtitle: String {
        switch self {
        case .englishV2: "Nur Englisch, höchste Trefferquote"
        case .multilingualV3: "25 Sprachen, inkl. Deutsch"
        }
    }

    var sizeLabel: String { "650 MB" }
    var accuracyDots: Int { 5 }
    var speedDots: Int { 5 }

    var asrVersion: AsrModelVersion {
        switch self {
        case .englishV2: .v2
        case .multilingualV3: .v3
        }
    }
}

/// Small indirection so HexModel does not depend on HexShared directly.
enum HexSettingsBridge {
    static var selectedModelID: String {
        UserDefaults(suiteName: "group.io.github.luraxx.hex")?.string(forKey: "selectedModelID")
            ?? "parakeet-tdt-0.6b-v3-coreml"
    }
}
