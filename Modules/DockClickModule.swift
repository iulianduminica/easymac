import Cocoa
import ApplicationServices

// Advanced DockClick implementation: clicking a Dock icon toggles minimize/hide and restore cycles.
final class DockClickModule: ModuleProtocol {
    let id = "dockclick"
    let displayName = "DockClick"
    let requiredPermissions: [ModulePermission] = [.accessibility]
    private(set) var isActive: Bool = false

    // MARK: Models
    struct DockItem { let rect: NSRect; let appName: String }
    enum DockOrientation { case left, bottom, right, unknown }
    private var dockItems: [DockItem] = []
    private var dockBounds: NSRect?
    private var dockScreen: NSScreen?
    private var dockBoundsOnScreen: NSRect?
    private var detectedDockOrientation: DockOrientation = .unknown

    // State tracking
    private var lastDockClickBundleID: String?
    private var lastDockClickAt: Date = .distantPast
    private enum DockClickAction { case passedForActivation, minimized, hid }
    private var lastActionByBundleID: [String: DockClickAction] = [:]

    // Behavior preference
    enum MinBehavior: String { case minimizeAll, hideApp }
    private(set) var minimizeBehavior: MinBehavior = {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: "DockClick_MinBehavior"), let val = MinBehavior(rawValue: raw) { return val }
        d.set(MinBehavior.minimizeAll.rawValue, forKey: "DockClick_MinBehavior")
        return .minimizeAll
    }()

    // Timers / attempts
    private var rescanTimer: Timer?
    private var pendingRescanAttempts = 0
    private let maxRescanAttempts = 3

    // MARK: Lifecycle
    func start() {
        guard !isActive else { return }
        isActive = true
        setupObservers()
        updateDockItems()
    }
    func stop() {
        guard isActive else { return }
        isActive = false
        NotificationCenter.default.removeObserver(self)
        rescanTimer?.invalidate(); rescanTimer = nil
        dockItems.removeAll()
    }

    // MARK: Observers
    private func setupObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(onDockRelatedChange), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(onDockRelatedChange), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(onDockRelatedChange), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }
    @objc private func onDockRelatedChange() {
        lastDockClickAt = Date() // reuse timestamp variable for change tracking
        pendingRescanAttempts = maxRescanAttempts
        rescanTimer?.invalidate()
        rescanTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.updateDockItems()
        }
    }

    // MARK: Dock Enumeration
    private func updateDockItems() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var items: [DockItem] = []
            if AXIsProcessTrusted(), let ax = self.fetchDockItemsUsingAX() { items = ax }
            else { items = self.fetchDockItemsViaAppleScript() }
            DispatchQueue.main.async { self.applyDockUpdate(items) }
        }
    }

    private func fetchDockItemsViaAppleScript() -> [DockItem] {
                var err: NSDictionary?
                guard let result = NSAppleScript(source: AppConst.AppleScript.dockEnumeration)?.executeAndReturnError(&err), err == nil else { return [] }
        var items: [DockItem] = []
        if result.descriptorType == typeAEList {
            for i in 1...result.numberOfItems {
                guard let item = result.atIndex(i), item.numberOfItems >= 4 else { continue }
                let pos = item.atIndex(1)
                let size = item.atIndex(2)
                let nameD = item.atIndex(3)
                let sub = item.atIndex(4)
                let subrole = sub?.stringValue ?? ""
                guard subrole == "AXApplicationDockItem" || subrole == "AXTrashDockItem" else { continue }
                let axX = pos?.atIndex(1)?.doubleValue ?? 0
                let axY = pos?.atIndex(2)?.doubleValue ?? 0
                let w = size?.atIndex(1)?.doubleValue ?? 0
                let h = size?.atIndex(2)?.doubleValue ?? 0
                let rect = convertAXRectToAppKit(axX: axX, axY: axY, width: w, height: h)
                let name = nameD?.stringValue ?? "Unknown"
                items.append(DockItem(rect: rect, appName: name))
            }
        }
        return items
    }

    private func fetchDockItemsUsingAX() -> [DockItem]? {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier else { return nil }
        let root = AXUIElementCreateApplication(pid)
        var out: [DockItem] = []
        func children(_ e: AXUIElement) -> [AXUIElement] { var v: CFTypeRef?; if AXUIElementCopyAttributeValue(e, kAXChildrenAttribute as CFString, &v) == .success, let arr = v as? [AXUIElement] { return arr }; return [] }
        func str(_ e: AXUIElement, _ a: CFString) -> String? { var v: CFTypeRef?; if AXUIElementCopyAttributeValue(e, a, &v) == .success { return v as? String }; return nil }
        func valPt(_ e: AXUIElement, _ a: CFString) -> CGPoint? { var v: CFTypeRef?; guard AXUIElementCopyAttributeValue(e, a, &v) == .success, let val = v else { return nil }; let axv = unsafeBitCast(val, to: AXValue.self); if AXValueGetType(axv) == .cgPoint { var p = CGPoint.zero; AXValueGetValue(axv, .cgPoint, &p); return p } ; return nil }
        func valSz(_ e: AXUIElement, _ a: CFString) -> CGSize? { var v: CFTypeRef?; guard AXUIElementCopyAttributeValue(e, a, &v) == .success, let val = v else { return nil }; let axv = unsafeBitCast(val, to: AXValue.self); if AXValueGetType(axv) == .cgSize { var s = CGSize.zero; AXValueGetValue(axv, .cgSize, &s); return s } ; return nil }
        func visit(_ n: AXUIElement) {
            if let sub = str(n, kAXSubroleAttribute as CFString), (sub == "AXApplicationDockItem" || sub == "AXTrashDockItem"), let p = valPt(n, kAXPositionAttribute as CFString), let s = valSz(n, kAXSizeAttribute as CFString) {
                let rect = convertAXRectToAppKit(axX: Double(p.x), axY: Double(p.y), width: Double(s.width), height: Double(s.height))
                let name = str(n, kAXTitleAttribute as CFString) ?? str(n, kAXDescriptionAttribute as CFString) ?? "Unknown"
                out.append(DockItem(rect: rect, appName: name))
                return
            }
            for c in children(n) { visit(c) }
        }
        visit(root)
        return out
    }

    private func applyDockUpdate(_ newItems: [DockItem]) {
        if newItems.isEmpty {
            if pendingRescanAttempts > 0 { pendingRescanAttempts -= 1; DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.updateDockItems() } }
            return
        }
        dockItems = newItems
        computeDockGeometry()
    }

    // MARK: Geometry
    private func computeDockGeometry() {
        guard !dockItems.isEmpty else { dockBounds = nil; dockScreen = nil; dockBoundsOnScreen = nil; detectedDockOrientation = .unknown; return }
        let bounds = dockItems.reduce(NSRect.null) { $0.union($1.rect) }
        dockBounds = bounds
        var best: NSScreen?; var bestArea: CGFloat = -1
        for s in NSScreen.screens { let inter = bounds.intersection(s.frame); let area = inter.width * inter.height; if area > bestArea { bestArea = area; best = s } }
        dockScreen = best
        dockBoundsOnScreen = best.map { bounds.intersection($0.frame) } ?? bounds
        if let s = best {
            let dB = abs(bounds.minY - s.frame.minY)
            let dL = abs(bounds.minX - s.frame.minX)
            let dR = abs(s.frame.maxX - bounds.maxX)
            let minD = min(dB, min(dL, dR))
            detectedDockOrientation = (minD == dB) ? .bottom : (minD == dL ? .left : .right)
        } else { detectedDockOrientation = .unknown }
    }
    private func convertAXRectToAppKit(axX: Double, axY: Double, width: Double, height: Double) -> NSRect {
        let union = NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }
        return NSRect(x: axX, y: Double(union.maxY) - axY - height, width: width, height: height)
    }
    private func convertGlobalPoint(_ p: CGPoint) -> CGPoint { let union = NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }; return CGPoint(x: p.x, y: union.maxY - p.y) }

    // MARK: Event Handling
    func handleLeftMouseDown(event: CGEvent) -> EventDecision {
        guard isActive else { return .continue }
        if (dockBounds == nil || dockScreen == nil) && !dockItems.isEmpty { computeDockGeometry() }
        let global = event.location
        let point = convertGlobalPoint(global)
        guard let zone = dockBoundsOnScreen ?? dockBounds, zone.insetBy(dx: -12, dy: -12).contains(point) else { return .continue }
        func expanded(_ r: NSRect) -> NSRect { r.insetBy(dx: -10, dy: -12) }
        guard let item = dockItems.first(where: { expanded($0.rect).contains(point) }) else { return .continue }
    let targetName = (item.appName == "Trash") ? "Finder" : item.appName
        guard let app = findRunningApp(named: targetName) else { return .continue }
        return processClick(on: app)
    }

    // MARK: Click semantics
    private func processClick(on app: NSRunningApplication) -> EventDecision {
        let bid = app.bundleIdentifier ?? "?"
        let now = Date()
        let lastAction = lastActionByBundleID[bid]
        let front = (NSWorkspace.shared.frontmostApplication?.bundleIdentifier == app.bundleIdentifier)
        UsageStats.shared.increment("dock_click")
        if lastAction == .minimized || lastAction == .hid { _ = restoreAppWindows(app); lastActionByBundleID[bid] = .passedForActivation; lastDockClickBundleID = bid; lastDockClickAt = now; return .consume }
        if front {
            if minimizeBehavior == .hideApp { app.hide(); lastActionByBundleID[bid] = .hid }
            else { minimizeApp(app); lastActionByBundleID[bid] = .minimized }
            lastDockClickBundleID = bid; lastDockClickAt = now; return .consume
        }
        if lastDockClickBundleID == bid && now.timeIntervalSince(lastDockClickAt) < 0.5 && lastAction == .passedForActivation {
            if minimizeBehavior == .hideApp { app.hide(); lastActionByBundleID[bid] = .hid }
            else { minimizeApp(app); lastActionByBundleID[bid] = .minimized }
            lastDockClickAt = now; return .consume
        }
        lastActionByBundleID[bid] = .passedForActivation
        lastDockClickBundleID = bid
        lastDockClickAt = now
        return .continue
    }

    // (Notification wording normalization) – DockClick currently silent; if future user feedback is added,
    // use titles like "Dock" and concise bodies similar to other modules (e.g., "Restored 3 window(s)").

    // MARK: App discovery
    private func findRunningApp(named name: String) -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications
        let exact = apps.filter { ($0.localizedName ?? "").caseInsensitiveCompare(name) == .orderedSame }
        if exact.count == 1 { return exact.first }
        if exact.count > 1 { return exact.first(where: { $0.isActive }) ?? exact.first }
        func norm(_ s: String) -> String { String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }) }
        let target = norm(name)
        var best: (NSRunningApplication, Int)?
        for a in apps {
            guard let n = a.localizedName else { continue }
            let nn = norm(n)
            var score = 0
            if nn == target { score += 100 }
            if nn.contains(target) || target.contains(nn) { score += 50 }
            if let bid = a.bundleIdentifier?.lowercased(), bid.contains(target) { score += 40 }
            if let last = a.bundleURL?.lastPathComponent.lowercased().replacingOccurrences(of: ".app", with: ""), norm(last) == target { score += 60 }
            if let cur = best { if score > cur.1 { best = (a, score) } } else { best = (a, score) }
        }
        return (best?.1 ?? 0) > 0 ? best!.0 : nil
    }

    // MARK: Minimize / Restore helpers
    private func minimizeApp(_ app: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var list: CFTypeRef?
        guard AXIsProcessTrusted(), AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &list) == .success, let windows = list as? [AXUIElement] else { app.hide(); return }
        var axWindows: [AXUIElement] = []
        for w in windows { var role: CFTypeRef?; if AXUIElementCopyAttributeValue(w, kAXRoleAttribute as CFString, &role) == .success, (role as? String) == "AXWindow" { axWindows.append(w) } }
        if axWindows.isEmpty { app.hide(); return }
        if axWindows.count == 1 {
            var mini: CFTypeRef?
            if AXUIElementCopyAttributeValue(axWindows[0], kAXMinimizedAttribute as CFString, &mini) == .success, let v = mini as? Bool, !v {
                _ = AXUIElementSetAttributeValue(axWindows[0], kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            } else { app.hide() }
            return
        }
        for w in axWindows { _ = AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanTrue) }
    }

    private func restoreAppWindows(_ app: NSRunningApplication) -> Int {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var list: CFTypeRef?
        guard AXIsProcessTrusted(), AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &list) == .success, let windows = list as? [AXUIElement] else { activate(app); return 0 }
        var restored = 0
        for w in windows {
            var role: CFTypeRef?; guard AXUIElementCopyAttributeValue(w, kAXRoleAttribute as CFString, &role) == .success, (role as? String) == "AXWindow" else { continue }
            var mini: CFTypeRef?; if AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &mini) == .success, let isMin = mini as? Bool, isMin {
                if AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success { restored += 1 }
            }
        }
        activate(app); return restored
    }
    private func activate(_ app: NSRunningApplication) { if #available(macOS 14.0, *) { app.activate() } else { app.activate(options: [.activateIgnoringOtherApps]) } }

    // MARK: Menu
    func moduleMenuItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        let behaviorRoot = NSMenuItem(title: "DockClick Behavior", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let minAll = NSMenuItem(title: "Minimize All Windows", action: #selector(selectMinimizeAll), keyEquivalent: "")
        minAll.state = minimizeBehavior == .minimizeAll ? .on : .off; minAll.target = self
        let hide = NSMenuItem(title: "Hide App", action: #selector(selectHideApp), keyEquivalent: "")
        hide.state = minimizeBehavior == .hideApp ? .on : .off; hide.target = self
        sub.addItem(minAll); sub.addItem(hide)
        behaviorRoot.submenu = sub
        items.append(behaviorRoot)
        let about = NSMenuItem(title: "About DockClick", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        items.append(about)
        return items
    }

    @objc private func selectMinimizeAll() { minimizeBehavior = .minimizeAll; UserDefaults.standard.set(minimizeBehavior.rawValue, forKey: "DockClick_MinBehavior") }
    @objc private func selectHideApp() { minimizeBehavior = .hideApp; UserDefaults.standard.set(minimizeBehavior.rawValue, forKey: "DockClick_MinBehavior") }

    @objc private func showAbout() {
        AboutDialogHelper.show(moduleName: "DockClick", summary: "Click Dock icons to minimize/hide, second click restores (Windows-style cycle).")
    }
}
