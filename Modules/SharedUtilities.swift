import Cocoa
import os
import UserNotifications

// MARK: - Logging
enum HubLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "EasyMac"
    static let general = Logger(subsystem: subsystem, category: "general")
    static let appleScript = Logger(subsystem: subsystem, category: "applescript")
    static let files = Logger(subsystem: subsystem, category: "files")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
    static let events = Logger(subsystem: subsystem, category: "events")
}

// Optional stdout mirroring for debugging
func debugPrintLog(_ category: String, _ message: String) {
    #if DEBUG
    fputs("[Hub][\(category)] \(message)\n", stderr)
    #endif
}

// MARK: - AppleScript
struct AppleScriptUtil {
    static func execute(_ source: String) -> Result<String, Error> {
        let start = CFAbsoluteTimeGetCurrent()
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        if let error = error {
            HubLog.appleScript.error("exec fail: \(error)")
            return .failure(NSError(domain: "AppleScript", code: 1, userInfo: ["raw": error]))
        }
        let out = result?.stringValue ?? ""
        HubLog.appleScript.debug("ok time=\(String(format: "%.2f", (CFAbsoluteTimeGetCurrent()-start)*1000))ms len=\(out.count)")
        return .success(out)
    }
}

// MARK: - Finder Selection
struct FinderSelectionHelper {
    static let separator = "|"

    static func selectedItems() -> [URL] {
        // Ensure Finder is running; if not, attempt to launch and skip selection this tick.
        if NSRunningApplication.runningApplications(withBundleIdentifier: AppConst.BundleID.finder).isEmpty {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: AppConst.BundleID.finder) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
            }
            return []
        }
        switch AppleScriptUtil.execute(AppConst.AppleScript.finderSelection) {
        case .failure:
            return []
        case .success(let raw):
            if raw == "NO_SELECTION" || raw == "NO_VALID_ITEMS" { return [] }
            if raw.hasPrefix("ERROR:") { return [] }
            return raw.split(separator: "|").compactMap { path in
                let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let url = URL(fileURLWithPath: trimmed)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
        }
    }

    static func currentDirectory() -> URL? {
        if NSRunningApplication.runningApplications(withBundleIdentifier: AppConst.BundleID.finder).isEmpty {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: AppConst.BundleID.finder) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
            }
            return nil
        }
        switch AppleScriptUtil.execute(AppConst.AppleScript.finderCurrentDirectory) {
        case .failure: return nil
        case .success(let raw):
            if raw.hasPrefix("ERROR:") { return nil }
            return URL(fileURLWithPath: raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

// MARK: - File Operations
struct FileOpsHelper {
    static func move(_ files: [URL], to destination: URL) -> (moved: Int, errors: [String]) {
        var moved = 0; var errs: [String] = []
        let fm = FileManager.default
        for src in files {
            guard fm.fileExists(atPath: src.path) else { errs.append("\(src.lastPathComponent): missing"); continue }
            var dst = destination.appendingPathComponent(src.lastPathComponent)
            if src.deletingLastPathComponent().standardized == destination.standardized { moved += 1; continue }
            var counter = 1
            while fm.fileExists(atPath: dst.path) {
                let base = src.deletingPathExtension().lastPathComponent
                let ext = src.pathExtension
                let newName = "\(base) \(counter)" + (ext.isEmpty ? "" : ".\(ext)")
                dst = destination.appendingPathComponent(newName)
                counter += 1
            }
            do { try fm.moveItem(at: src, to: dst); moved += 1 }
            catch { errs.append("\(src.lastPathComponent): \(error.localizedDescription)") }
        }
        return (moved, errs)
    }

    static func trash(_ files: [URL]) -> (trashed: Int, errors: [String]) {
        var t = 0; var errs: [String] = []
        for f in files {
            do { try FileManager.default.trashItem(at: f, resultingItemURL: nil); t += 1 }
            catch { errs.append("\(f.lastPathComponent): \(error.localizedDescription)") }
        }
        return (t, errs)
    }
}

// MARK: - Debounce
final class DebounceTimer {
    private var lastFire: TimeInterval = 0
    private let interval: TimeInterval
    init(interval: TimeInterval) { self.interval = interval }
    func shouldAllow(now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        if now - lastFire < interval { return false }
        lastFire = now
        return true
    }
}

// MARK: - Permissions (Skeleton)
final class PermissionsManager {
    static let shared = PermissionsManager()
    private init() {}

    func accessibilityGranted() -> Bool { AXIsProcessTrusted() }
    func notificationsGranted(_ cb: @escaping (Bool)->Void) {
        UNUserNotificationCenter.current().getNotificationSettings { s in cb(s.authorizationStatus == .authorized) }
    }
    func requestNotifications(_ cb: @escaping (Bool)->Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    cb(granted)
                }
            case .denied:
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Notifications Are Disabled"
                    alert.informativeText = "To see EasyMac notifications, enable them in System Settings → Notifications → EasyMac."
                    alert.addButton(withTitle: "Open Settings")
                    alert.addButton(withTitle: "Cancel")
                    let resp = alert.runModal()
                    if resp == .alertFirstButtonReturn { self.openNotificationSettings() }
                    cb(false)
                }
            case .authorized, .provisional, .ephemeral:
                cb(true)
            @unknown default:
                cb(false)
            }
        }
    }

    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Onboarding Deferral / Suppression
    private let defaults = UserDefaults.standard
    private let kDeferralKey = "PermissionsDeferralTime"
    private let kSuppressKey = "PermissionsSuppressOnboarding"
    private let deferralInterval: TimeInterval = 6 * 60 * 60 // 6 hours

    func shouldShowOnboarding(now: TimeInterval = Date().timeIntervalSince1970) -> Bool {
        if defaults.bool(forKey: kSuppressKey) { return false }
        if accessibilityGranted() { // Only show if missing something
            var granted = true
            let group = DispatchGroup(); group.enter()
            var notifGranted = true
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                notifGranted = (settings.authorizationStatus == .authorized)
                group.leave()
            }
            group.wait()
            granted = granted && notifGranted
            if granted { return false }
        }
        let last = defaults.double(forKey: kDeferralKey)
        if last == 0 { return true }
        return (now - last) > deferralInterval
    }

    enum OnboardingChoice { case fixNow, remindLater, dontAsk }
    func record(choice: OnboardingChoice) {
        switch choice {
        case .fixNow:
            defaults.removeObject(forKey: kDeferralKey)
        case .remindLater:
            defaults.set(Date().timeIntervalSince1970, forKey: kDeferralKey)
        case .dontAsk:
            defaults.set(true, forKey: kSuppressKey)
        }
    }
    func clearSuppression() { defaults.removeObject(forKey: kSuppressKey) }
}

// MARK: - Notification Wrapper
struct Notifier {
    private static var recent: [(t: TimeInterval, h: String)] = []
    private static let queue = DispatchQueue(label: "notifier.rate", qos: .utility)
    // Max 5 notifications / 10s window; suppress duplicates within last 3s.
    static func show(title: String, body: String) {
        queue.async {
            let now = Date().timeIntervalSince1970
            recent = recent.filter { now - $0.t < 10 }
            let hash = title + "|" + body
            if recent.filter({ hash == $0.h }).contains(where: { now - $0.t < 3 }) { return }
            if recent.count >= 5 { return }
            recent.append((now, hash))
            DispatchQueue.main.async {
                let content = UNMutableNotificationContent()
                content.title = "EasyMac • " + title
                content.body = body
                content.sound = .default
                let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
            }
        }
    }
}

// MARK: - About Dialog Helper
struct AboutDialogHelper {
    static func show(moduleName: String, summary: String) {
        let alert = NSAlert()
        alert.messageText = moduleName
        alert.informativeText = summary + "\n\nPart of EasyMac."
        alert.runModal()
    }
}
