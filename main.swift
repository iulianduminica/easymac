// EasyMac main entry point
// Consolidated micro-utilities (TrashKey, CutPaste, DockClick) under one hub.

import Cocoa
import UserNotifications
import ServiceManagement

class HubAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private var modules: [ModuleProtocol] = []
    private var healthTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set notification delegate to show banners while app is foreground/background
        UNUserNotificationCenter.current().delegate = self
        // Register modules
        modules = [TrashKeyModule(), CutPasteModule(), DockClickModule()]
        ModuleRegistry.shared.register(modules)
        EventRouter.shared.start()
        setupStatusItem()
        NotificationCenter.default.addObserver(self, selector: #selector(onModuleToggle(_:)), name: .moduleEnablementChanged, object: nil)
        presentPermissionsOnboardingIfNeeded()
        startHealthTimer()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gearshape.2", accessibilityDescription: "EasyMac")
            button.toolTip = "EasyMac"
        }
        rebuildMenu()
    }

    @objc private func onModuleToggle(_ note: Notification) { rebuildMenu() }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "EasyMac", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        // Global pause/resume
        let paused = ModuleRegistry.shared.globallyPaused
        let pauseItem = NSMenuItem(title: paused ? "Resume All Modules" : "Pause All Modules", action: #selector(toggleGlobalPause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        // Health status
        let healthy = EventRouter.shared.isHealthy()
        let healthItem = NSMenuItem(title: "Input Tap: " + (healthy ? "OK" : "ISSUE"), action: #selector(manualRecoverTap), keyEquivalent: "")
        healthItem.target = self
        menu.addItem(healthItem)
        if !healthy {
            let detail = NSMenuItem(title: "Attempt recovery…", action: #selector(manualRecoverTap), keyEquivalent: "")
            detail.target = self
            menu.addItem(detail)
        }
        menu.addItem(.separator())
        // Permissions summary
        let acc = PermissionsManager.shared.accessibilityGranted()
        let notifStatusItem = NSMenuItem(title: "Checking notification permission…", action: nil, keyEquivalent: "")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notifStatusItem.title = "Notifications: " + (settings.authorizationStatus == .authorized ? "✅" : "⚠️")
            }
        }
        let accessItem = NSMenuItem(title: "Accessibility: " + (acc ? "✅" : "⚠️"), action: #selector(requestAccessibility), keyEquivalent: "")
        accessItem.target = self
        menu.addItem(accessItem)
        menu.addItem(notifStatusItem)
        let requestNotif = NSMenuItem(title: "Request Notification Permission…", action: #selector(requestNotifications), keyEquivalent: "")
        requestNotif.target = self
        menu.addItem(requestNotif)
        if #available(macOS 13.0, *) {
            let openSettings = NSMenuItem(title: "Open Notification Settings…", action: #selector(openNotificationSettings), keyEquivalent: "")
            openSettings.target = self
            menu.addItem(openSettings)
        }
        menu.addItem(.separator())
        // Login item controls
        if #available(macOS 13.0, *) {
            let isLogin = (SMAppService.mainApp.status == .enabled)
            let loginItem = NSMenuItem(title: isLogin ? "Remove from Login Items" : "Add to Login Items", action: #selector(toggleLoginItem), keyEquivalent: "")
            loginItem.target = self
            menu.addItem(loginItem)
            menu.addItem(.separator())
        }
    // Preferences
    let prefs = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
    prefs.target = self
    menu.addItem(prefs)
        menu.addItem(.separator())

        // Module submenus
        for m in modules {
            let enabled = ModuleRegistry.shared.isEnabled(m)
            let statusSuffix = ModuleRegistry.shared.globallyPaused ? " (Paused)" : (enabled ? "" : " (Disabled)")
            let root = NSMenuItem(title: m.displayName + statusSuffix, action: nil, keyEquivalent: "")
            let sub = NSMenu()
            let toggle = NSMenuItem(title: enabled ? "Disable Module" : "Enable Module", action: #selector(toggleModule(_:)), keyEquivalent: "")
            toggle.representedObject = m.id
            toggle.target = self
            sub.addItem(toggle)
            if !m.moduleMenuItems().isEmpty { sub.addItem(.separator()) }
            for item in m.moduleMenuItems() { sub.addItem(item) }
            root.submenu = sub
            menu.addItem(root)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func toggleLoginItem() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch { }
        rebuildMenu()
    }

    @objc private func requestAccessibility() {
        if !PermissionsManager.shared.accessibilityGranted() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
        }
    }

    @objc private func requestNotifications() {
        PermissionsManager.shared.requestNotifications { granted in
            DispatchQueue.main.async { self.rebuildMenu() }
        }
    }

    @objc private func openNotificationSettings() {
        if #available(macOS 13.0, *) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications?EasyMac") {
                NSWorkspace.shared.open(url)
            } else if let url2 = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                NSWorkspace.shared.open(url2)
            }
        }
    }

    @objc private func toggleModule(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let module = modules.first(where: { $0.id == id }) else { return }
        let currentlyEnabled = ModuleRegistry.shared.isEnabled(module)
        ModuleRegistry.shared.setEnabled(!currentlyEnabled, for: module)
        rebuildMenu()
    }

    @objc private func quitApp() { NSApplication.shared.terminate(nil) }

    @objc private func manualRecoverTap() {
        let before = EventRouter.shared.isHealthy()
        let result = EventRouter.shared.attemptRecovery()
        if result && !before {
            Notifier.show(title: "Input Monitoring", body: "Event tap manually restored")
        } else if !result {
            Notifier.show(title: "Input Monitoring", body: "Recovery failed – check Accessibility permission")
        }
        rebuildMenu()
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func toggleGlobalPause() {
        let paused = ModuleRegistry.shared.globallyPaused
        ModuleRegistry.shared.setGlobalPaused(!paused)
        Notifier.show(title: "Modules", body: paused ? "All modules resumed" : "All modules paused")
        rebuildMenu()
    }

    // MARK: Permissions Onboarding
    private func presentPermissionsOnboardingIfNeeded() {
        guard PermissionsManager.shared.shouldShowOnboarding() else { return }
        // Determine missing permissions
        let accMissing = !PermissionsManager.shared.accessibilityGranted()
        var notifMissing = false
        let group = DispatchGroup(); group.enter()
        UNUserNotificationCenter.current().getNotificationSettings { s in
            notifMissing = (s.authorizationStatus != .authorized)
            group.leave()
        }
        group.wait()
        var body: [String] = []
        if accMissing { body.append("• Accessibility – needed to monitor keys & click events") }
        if notifMissing { body.append("• Notifications – status & feedback messages") }
        if body.isEmpty { return }
        let alert = NSAlert()
        alert.messageText = "Enable Permissions"
    alert.informativeText = "EasyMac works best with:\n\n" + body.joined(separator: "\n") + "\n\nChoose an action:"
        alert.addButton(withTitle: "Fix Now")      // first
        alert.addButton(withTitle: "Remind Later") // second
        alert.addButton(withTitle: "Don't Ask Again") // third
        let resp = alert.runModal()
        switch resp {
        case .alertFirstButtonReturn:
            PermissionsManager.shared.record(choice: .fixNow)
            if accMissing { requestAccessibility() }
            if notifMissing { requestNotifications() }
        case .alertSecondButtonReturn:
            PermissionsManager.shared.record(choice: .remindLater)
        case .alertThirdButtonReturn:
            PermissionsManager.shared.record(choice: .dontAsk)
        default: break
        }
    }

    // MARK: UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    // MARK: Health Timer
    private func startHealthTimer() {
        healthTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            let acc = PermissionsManager.shared.accessibilityGranted()
            if acc && !EventRouter.shared.isHealthy() {
                let ok = EventRouter.shared.attemptRecovery()
                if ok {
                    Notifier.show(title: "Input Monitoring Restored", body: "Event tap recovered after interruption")
                } else {
                    Notifier.show(title: "Input Monitoring Issue", body: "Unable to recover event tap; check Accessibility permission")
                    if EventRouter.shared.consecutiveFailures == 3 {
                        Notifier.show(title: "Input Monitoring", body: "Multiple failures (3). Consider relaunching app or re-enabling permission.")
                    } else if EventRouter.shared.consecutiveFailures == 5 {
                        Notifier.show(title: "Input Monitoring", body: "5 consecutive failures – final notice until next success")
                    }
                }
            }
            DispatchQueue.main.async { self.rebuildMenu() }
        }
    }
}

// Manual entry point (avoid @main due to other top-level declarations in modules).
let app = NSApplication.shared
let delegate = HubAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
