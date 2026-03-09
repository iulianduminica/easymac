import Cocoa

final class CutPasteModule: ModuleProtocol {
    let id = "cutpaste"
    let displayName = "CutPaste"
    let requiredPermissions: [ModulePermission] = [.accessibility, .notifications, .automation]
    private(set) var isActive: Bool = false

    private var cutFiles: [URL] = []

    func start() { isActive = true }
    func stop() { isActive = false; cutFiles.removeAll() }

    func handleKeyDown(event: CGEvent) -> EventDecision {
        guard isActive else { return .continue }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == AppConst.BundleID.finder else { return .continue }
        // Avoid intercepting shortcuts while typing in Finder (e.g., renaming files, search fields)
        if isTextEditingInFinder() { return .continue }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        guard flags.contains(.maskCommand) else { return .continue }
        switch keyCode {
        case AppConst.KeyCode.x:
            return performCut() ? .consume : .continue
        case AppConst.KeyCode.v:
            return performPaste() ? .consume : .continue
        default:
            return .continue
        }
    }

    @discardableResult
    private func performCut() -> Bool {
        let selection = FinderSelectionHelper.selectedItems()
        guard !selection.isEmpty else { return false }
        cutFiles = selection
        // Do not clear the general pasteboard here; since we consume the event, Finder won't copy.
        Notifier.show(title: "Cut", body: "Ready to move \(cutFiles.count) file(s)")
        UsageStats.shared.increment("cut", by: cutFiles.count)
        return true
    }

    @discardableResult
    private func performPaste() -> Bool {
        guard !cutFiles.isEmpty else { return false }
        guard let dest = FinderSelectionHelper.currentDirectory() else {
            Notifier.show(title: "Paste", body: "No destination directory detected")
            return false
        }
        let existing = cutFiles.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { cutFiles.removeAll(); return false }
        cutFiles = existing
        let result = FileOpsHelper.move(cutFiles, to: dest)
        var body = "Moved \(result.moved)/\(cutFiles.count) file(s)"
        if !result.errors.isEmpty { body += " (\(result.errors.count) error(s))" }
        Notifier.show(title: "Paste", body: body)
        UsageStats.shared.increment("paste", by: result.moved)
        cutFiles.removeAll()
        NSPasteboard.general.clearContents() // optional: clear after successful move
        return result.moved > 0
    }

    func moduleMenuItems() -> [NSMenuItem] {
        let about = NSMenuItem(title: "About CutPaste", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        return [about]
    }

    @objc private func showAbout() {
        AboutDialogHelper.show(moduleName: "CutPaste", summary: "Adds Windows-style Cut (Cmd+X) and Paste (Cmd+V) move semantics for Finder files.")
    }

    // MARK: - Focus Utility
    private func isTextEditingInFinder() -> Bool {
        // Requires Accessibility permission; if not granted, be conservative and allow handling.
        guard AXIsProcessTrusted() else { return false }
        let sys = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let err = AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focused)
        guard err == .success, let elem = focused else { return false }
        var roleValue: AnyObject?
        if AXUIElementCopyAttributeValue(elem as! AXUIElement, kAXRoleAttribute as CFString, &roleValue) == .success,
           let role = roleValue as? String, role == kAXTextFieldRole as String || role == kAXTextAreaRole as String {
            return true
        }
        return false
    }
}
