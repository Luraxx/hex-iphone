import Foundation

/// Cross-process notifications (app -> keyboard) via the Darwin notification center.
/// Payload-free; the receiver reads current state from the TranscriptStore.
public enum DarwinNotify {
    public static func post(_ name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }
}

/// Observes a Darwin notification for the lifetime of this instance.
/// The handler runs on an arbitrary thread — dispatch to main for UI work.
public final class DarwinNotificationObserver {
    private let name: String
    private let handler: () -> Void

    public init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let instance = Unmanaged<DarwinNotificationObserver>.fromOpaque(observer).takeUnretainedValue()
                instance.handler()
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(name as CFString),
            nil
        )
    }
}
