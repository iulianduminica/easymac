import Cocoa

/// Central registry retaining all modules and providing lookup & lifecycle.
final class ModuleRegistry {
    static let shared = ModuleRegistry()
    private init() {}

    private(set) var modules: [ModuleProtocol] = []
    private let defaults = UserDefaults.standard
    private let enabledKeyPrefix = "ModuleEnabled_"
    private let globalPauseKey = "ModulesGloballyPaused"
    private(set) var globallyPaused: Bool = false

    /// Register modules (call early at launch). Start those previously enabled.
    func register(_ modules: [ModuleProtocol]) {
        self.modules = modules
        globallyPaused = defaults.bool(forKey: globalPauseKey)
        for m in modules where isEnabled(m) { m.start() }
    }

    func isEnabled(_ module: ModuleProtocol) -> Bool {
        let key = enabledKeyPrefix + module.id
        if defaults.object(forKey: key) == nil { return true } // default to enabled first run
        return defaults.bool(forKey: key) && !globallyPaused
    }

    func setEnabled(_ enabled: Bool, for module: ModuleProtocol) {
        let key = enabledKeyPrefix + module.id
        defaults.set(enabled, forKey: key)
        if globallyPaused { return }
        if enabled { module.start() } else { module.stop() }
        NotificationCenter.default.post(name: .moduleEnablementChanged, object: module)
    }

    func setGlobalPaused(_ paused: Bool) {
        guard paused != globallyPaused else { return }
        globallyPaused = paused
        defaults.set(paused, forKey: globalPauseKey)
        if paused {
            for m in modules where m.isActive { m.stop() }
        } else {
            for m in modules where isEnabled(m) { m.start() }
        }
        NotificationCenter.default.post(name: .moduleEnablementChanged, object: nil)
    }
}

extension Notification.Name { static let moduleEnablementChanged = Notification.Name("ModuleEnablementChanged") }
