# Module Development Guide

This document describes how to add new micro-utilities ("modules") to Macwin Toolset.

## Overview
Modules encapsulate a focused feature (e.g., TrashKey, CutPaste, DockClick) and plug into a shared event tap plus shared services (notifications, AppleScript helpers, logging).

## Contract (`ModuleProtocol`)
Key requirements:
- `id`: Stable lowercase identifier (used in persistence keys). Avoid spaces.
- `displayName`: Human-readable name shown in menus.
- `requiredPermissions`: Declare any of: `.accessibility`, `.notifications`, `.automation`.
- Lifecycle: `start()` and `stop()` are invoked when the module is enabled/disabled via the UI or at app launch.
- Event handling (optional): `handleKeyDown(event:)`, `handleLeftMouseDown(event:)`—return `.consume` to stop propagation.
- Menu customization: Return additional `NSMenuItem`s from `moduleMenuItems()` (the hub adds an enable/disable wrapper automatically).

## File Placement
Place new module source file in `Modules/` named `<FeatureName>Module.swift` (CamelCase). Example: `WindowSnapModule.swift`.

## Minimal Template
```swift
import Cocoa

final class TemplateModule: ModuleProtocol {
    let id = "template"
    let displayName = "Template"
    let requiredPermissions: [ModulePermission] = [.accessibility]
    private(set) var isActive = false

    func start() { isActive = true }
    func stop()  { isActive = false }

    func handleKeyDown(event: CGEvent) -> EventDecision { return .continue }
    func moduleMenuItems() -> [NSMenuItem] {
        let about = NSMenuItem(title: "About Template", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        return [about]
    }

    @objc private func showAbout() {
        AboutDialogHelper.show(moduleName: "Template", summary: "Describe the feature succinctly.")
    }
}
```

## Shared Utilities
- Logging: `HubLog.general.debug("message")`
- AppleScript: `AppleScriptUtil.execute(source)`
- Finder selections: `FinderSelectionHelper.selectedItems()` / `.currentDirectory()`
- File ops: `FileOpsHelper.move(...)`, `FileOpsHelper.trash(...)`
- Notifications: `Notifier.show(title: "Feature", body: "Message")`
- Permissions: Automatically aggregated; declare requirements only.

## Adding the Module
1. Create file in `Modules/`.
2. Add class implementing `ModuleProtocol`.
3. Register in `main.swift` module array (order controls submenu ordering).
4. Build & run; the module defaults to enabled first launch.

## Guidelines
- Keep blocking work off the main thread (use `DispatchQueue.global`).
- Debounce repeated actions with `DebounceTimer` if responding to raw key events.
- Avoid presenting alerts directly; prefer notifications or menu affordances.
- Use concise, action-focused notification wording (Title: single word or short phrase; Body: past-tense result).

## Testing Tips
- Temporarily add verbose `debugPrintLog` statements guarded by `#if DEBUG`.
- Simulate permission absence by revoking Accessibility in System Settings and observing recovery messages.

## Future Extensions (Planned)
- Runtime module discovery (dynamic loading)
- Preferences UI with per-module settings

Contributions aligning with this contract remain easy to review and integrate.
