import Cocoa

/// Permissions a module can request/require.
enum ModulePermission: String, CaseIterable {
    case accessibility
    case notifications
    case automation // AppleEvents / Scripting
}

/// Basic result of handling an event: allow it to continue or consume it.
enum EventDecision { case `continue`, consume }

/// Protocol all micro-tools (modules) must adopt.
protocol ModuleProtocol: AnyObject {
    /// Stable unique identifier (used for preferences persistence)
    var id: String { get }
    /// Human friendly name for menus/UI.
    var displayName: String { get }
    /// Declared permissions required for functioning; hub aggregates & prompts.
    var requiredPermissions: [ModulePermission] { get }
    /// Whether the module is currently active (started).
    var isActive: Bool { get }

    /// Called when hub is ready; perform lightweight initialization only.
    func start()
    /// Called on module disable or hub shutdown; release taps/timers.
    func stop()

    /// Optional: supply menu items (excluding enable/disable wrapper added by hub).
    func moduleMenuItems() -> [NSMenuItem]

    /// Optional: key event handler (CGEvent variant). Return .consume to block event propagation.
    func handleKeyDown(event: CGEvent) -> EventDecision
    /// Optional: mouse event handler (e.g., left clicks) return decision.
    func handleLeftMouseDown(event: CGEvent) -> EventDecision
}

extension ModuleProtocol {
    func moduleMenuItems() -> [NSMenuItem] { return [] }
    func handleKeyDown(event: CGEvent) -> EventDecision { return .continue }
    func handleLeftMouseDown(event: CGEvent) -> EventDecision { return .continue }
}
