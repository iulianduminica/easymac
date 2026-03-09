import Cocoa

final class TrashKeyModule: ModuleProtocol {
    let id = "trashkey"
    let displayName = "TrashKey"
    let requiredPermissions: [ModulePermission] = [.accessibility, .notifications, .automation]
    private(set) var isActive: Bool = false

    private let debounce = DebounceTimer(interval: 0.3)
    private var reentrancyGuard = false

    func start() { isActive = true }
    func stop() { isActive = false }

    func handleKeyDown(event: CGEvent) -> EventDecision {
        guard isActive else { return .continue }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    guard keyCode == AppConst.KeyCode.delete else { return .continue }
        // Finder gate
    if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != AppConst.BundleID.finder { return .continue }
        // Modifier check
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate) || flags.contains(.maskShift) { return .continue }
        if !debounce.shouldAllow() { return .consume }
        if reentrancyGuard { return .consume }
        reentrancyGuard = true
        let selection = FinderSelectionHelper.selectedItems()
        if selection.isEmpty { reentrancyGuard = false; return .continue }
        let result = FileOpsHelper.trash(selection)
        if result.trashed > 0 {
            var msg = "Moved \(result.trashed) file(s) to Trash"
            if !result.errors.isEmpty { msg += " (\(result.errors.count) error(s))" }
            Notifier.show(title: "Trash", body: msg)
            UsageStats.shared.increment("trash_success", by: result.trashed)
        } else {
            Notifier.show(title: "Trash", body: "No files moved (nothing selected)")
            UsageStats.shared.increment("trash_empty")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.reentrancyGuard = false }
        return .consume
    }

    func moduleMenuItems() -> [NSMenuItem] {
        let about = NSMenuItem(title: "About TrashKey", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        return [about]
    }

    @objc private func showAbout() {
        AboutDialogHelper.show(moduleName: "TrashKey", summary: "Enable Windows-style single Delete key to move files to Trash in Finder.")
    }
}
