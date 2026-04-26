import ObjectiveC
import SwiftUI
import UIKit

/// Latest `onShake` callback for the key window hook (set from SwiftUI; avoid retaining stale captures).
fileprivate enum OnShakeState {
    static var perform: (() -> Void)?
}

/// Subclass in place of `UIWindow` so the key window can observe shake by forwarding `UIEvent` / `UIResponder` motion.
/// Must not add stored instance properties: installed via `object_setClass` on an existing `UIWindow` instance.
final class ShakeDetectingWindow: UIWindow {
    private static var lastShakeTime: TimeInterval = 0
    private static let minShakeInterval: TimeInterval = 0.45

    private static func handleShake() {
        let t = CACurrentMediaTime()
        guard t - lastShakeTime >= minShakeInterval else { return }
        lastShakeTime = t
        OnShakeState.perform?()
    }

    /// Primary path: motion events for shake pass through the window.
    override func sendEvent(_ event: UIEvent) {
        if event.type == .motion, event.subtype == .motionShake {
            Self.handleShake()
        }
        super.sendEvent(event)
    }

    /// Responder-path motion: kept so shake is handled whether the event is delivered as `UIEvent` or as `UIResponder` callbacks.
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            Self.handleShake()
        }
        super.motionEnded(motion, with: event)
    }
}

private enum KeyWindowShaker {
    private static var installAttempts = 0
    private static let maxInstallAttempts = 5

    /// Resets the retry counter so a view that re-enters the hierarchy can patch the key window again.
    static func tryInstallShakeWindowClass() {
        installAttempts = 0
        installNowOrRetry()
    }

    private static func installNowOrRetry() {
        guard let key = findKeyWindow() else {
            installAttempts += 1
            guard installAttempts < maxInstallAttempts else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { installNowOrRetry() }
            return
        }
        object_setClass(key, ShakeDetectingWindow.self)
    }

    private static func findKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

struct OnShakeModifier: ViewModifier {
    let perform: () -> Void

    func body(content: Content) -> some View {
        _ = (OnShakeState.perform = perform)
        return content
            .onAppear {
                KeyWindowShaker.tryInstallShakeWindowClass()
            }
            .onDisappear {
                OnShakeState.perform = nil
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        modifier(OnShakeModifier(perform: action))
    }
}
