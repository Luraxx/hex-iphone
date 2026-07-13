import HexShared
import SwiftUI

@main
struct HexApp: App {
    // Creates the AppModel at process start — including background launches
    // via App Intents (Action Button) — so the DictationBridge is registered.
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onOpenURL { url in
                    guard url.scheme == SharedConstants.urlScheme else { return }
                    switch url.host {
                    case "toggle":
                        Task { await AppModel.shared.toggleDictation() }
                    default:
                        break
                    }
                }
                .onChange(of: scenePhase) {
                    // Foreground visits refresh the standby Live Activity (its
                    // start is foreground-only) and retry rejected clipboard writes.
                    if scenePhase == .active {
                        AppModel.shared.appBecameActive()
                    }
                }
        }
    }
}
