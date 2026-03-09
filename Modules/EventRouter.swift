import Cocoa
import ApplicationServices

/// Routes low-level CGEvents to interested modules via a single tap.
final class EventRouter {
    static let shared = EventRouter()
    private init() {}

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    private var lastStartAttempt: TimeInterval = 0
    private(set) var lastSuccessfulStart: TimeInterval = 0
    private(set) var lastRecoveryAttempt: TimeInterval = 0
    private(set) var lastRecoverySuccess: TimeInterval = 0
    private var globalDebounceLast: TimeInterval = 0
    private let globalDebounceInterval: TimeInterval = 0.02 // 20ms guard
    private(set) var consecutiveFailures: Int = 0
    private(set) var lastFailureTime: TimeInterval = 0

    // Key codes now sourced from AppConst.KeyCode

    func start() {
        guard !isRunning else { return }
        guard AXIsProcessTrusted() else {
            // Prompt once; user flow managed by PermissionsManager later
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            return
        }
        lastStartAttempt = Date().timeIntervalSince1970
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let router = Unmanaged<EventRouter>.fromOpaque(refcon).takeUnretainedValue()
                return router.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap = eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        lastSuccessfulStart = Date().timeIntervalSince1970
    }

    func stop() {
        guard isRunning else { return }
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let s = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), s, .commonModes) }
        eventTap = nil; runLoopSource = nil; isRunning = false
    }

    // MARK: Health & Recovery
    func isHealthy() -> Bool {
        guard isRunning, let tap = eventTap else { return false }
        return CFMachPortIsValid(tap)
    }

    /// Attempt to recover the event tap if permissions exist. Returns true if healthy after attempt.
    @discardableResult
    func attemptRecovery() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        if isHealthy() { return true }
        lastRecoveryAttempt = Date().timeIntervalSince1970
        // Full restart sequence
        stop()
        start()
        if isHealthy() { lastRecoverySuccess = Date().timeIntervalSince1970; consecutiveFailures = 0; return true }
        consecutiveFailures += 1
        lastFailureTime = Date().timeIntervalSince1970
        return false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    guard NSWorkspace.shared.frontmostApplication != nil else { return Unmanaged.passUnretained(event) }
    // For now, only TrashKey & CutPaste require Finder gating; DockClick only on mouse events.
        let now = CFAbsoluteTimeGetCurrent()
        func globalDebounceTrip() -> Bool {
            if now - globalDebounceLast < globalDebounceInterval { return true }
            globalDebounceLast = now; return false
        }

        switch type {
        case .keyDown:
            if globalDebounceTrip() { return Unmanaged.passUnretained(event) }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if [AppConst.KeyCode.delete, AppConst.KeyCode.x, AppConst.KeyCode.v].contains(keyCode) {
                for module in ModuleRegistry.shared.modules where ModuleRegistry.shared.isEnabled(module) {
                    // Provide Finder gating inside module if necessary
                    let decision = module.handleKeyDown(event: event)
                    if decision == .consume { return nil }
                }
            }
            return Unmanaged.passUnretained(event)
        case .leftMouseDown:
            if globalDebounceTrip() { return Unmanaged.passUnretained(event) }
            // Only relevant to DockClick style module; let module decide.
            for module in ModuleRegistry.shared.modules where ModuleRegistry.shared.isEnabled(module) {
                let decision = module.handleLeftMouseDown(event: event)
                if decision == .consume { return nil }
            }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
