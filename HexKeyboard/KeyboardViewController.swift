import HexShared
import SwiftUI
import UIKit

/// The Hex keyboard: auto-inserts the latest transcript into the active text field.
/// Keyboard extensions cannot access the microphone — recording is done by the app
/// (Action Button); hand-off happens via the App Group container + Darwin notification.
final class KeyboardViewController: UIInputViewController {
    private let state = KeyboardState()
    private let store = TranscriptStore.shared
    private var darwinObserver: DarwinNotificationObserver?
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        let keyboardView = KeyboardView(
            state: state,
            insertText: { [weak self] text in self?.insertSmart(text) },
            deleteBackward: { [weak self] in self?.textDocumentProxy.deleteBackward() },
            insertNewline: { [weak self] in self?.textDocumentProxy.insertText("\n") },
            insertSpace: { [weak self] in self?.textDocumentProxy.insertText(" ") },
            switchKeyboard: { [weak self] in self?.advanceToNextInputMode() },
            openApp: { [weak self] in self?.openContainerApp() }
        )

        let host = UIHostingController(rootView: keyboardView)
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
        host.view.backgroundColor = .clear

        let height = view.heightAnchor.constraint(equalToConstant: 250)
        height.priority = UILayoutPriority(999)
        height.isActive = true
        heightConstraint = height

        // Live signal from the app: new transcript ready -> insert immediately.
        darwinObserver = DarwinNotificationObserver(name: SharedConstants.Darwin.newTranscript) { [weak self] in
            DispatchQueue.main.async {
                self?.refresh()
                self?.attemptAutoInsert()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
        attemptAutoInsert()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        state.needsInputModeSwitchKey = needsInputModeSwitchKey
    }

    // MARK: - Data

    private func refresh() {
        state.hasFullAccess = hasFullAccess
        state.storeAvailable = store.isAvailable
        state.recent = Array(store.all().prefix(5))
    }

    /// Inserts the queued transcript exactly once (auto-insertion).
    private func attemptAutoInsert() {
        guard hasFullAccess, store.isAvailable, SharedSettings.autoInsert else { return }
        guard let pending = store.pendingForInsertion() else { return }
        store.markPendingConsumed(id: pending.id)
        insertSmart(pending.text)
        state.flashInserted()
        // Belt & suspenders: iOS may have rejected the app's background pasteboard
        // write; the keyboard (full access) copies again so paste works everywhere.
        if SharedSettings.autoCopy {
            UIPasteboard.general.string = pending.text
        }
    }

    /// Inserts with a leading space when the cursor sits right after a word.
    private func insertSmart(_ text: String) {
        var output = text
        if let before = textDocumentProxy.documentContextBeforeInput,
           let last = before.last,
           !last.isWhitespace, !last.isNewline {
            output = " " + output
        }
        textDocumentProxy.insertText(output)
    }

    // MARK: - Opening the app (responder-chain workaround, extensions have no openURL)

    private func openContainerApp() {
        guard let url = URL(string: "\(SharedConstants.urlScheme)://") else { return }
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current !== self, current.responds(to: selector) {
                current.perform(selector, with: url)
                return
            }
            responder = current.next
        }
        extensionContext?.open(url, completionHandler: nil)
    }
}
