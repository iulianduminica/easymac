import SwiftUI
import Combine

// Model bridging ModuleRegistry state into SwiftUI bindings.
final class PreferencesModel: ObservableObject {
    @Published var modules: [ModuleProtocol] = []
    @Published var globallyPaused: Bool = false

    init() {
        refresh()
        NotificationCenter.default.addObserver(self, selector: #selector(onChange(_:)), name: .moduleEnablementChanged, object: nil)
    }

    func refresh() {
        modules = ModuleRegistry.shared.modules
        globallyPaused = ModuleRegistry.shared.globallyPaused
        objectWillChange.send()
    }

    func toggle(module: ModuleProtocol) {
        let enabled = ModuleRegistry.shared.isEnabled(module)
        ModuleRegistry.shared.setEnabled(!enabled, for: module)
        refresh()
    }

    func toggleGlobalPause() {
        ModuleRegistry.shared.setGlobalPaused(!ModuleRegistry.shared.globallyPaused)
        refresh()
    }

    @objc private func onChange(_ note: Notification) { refresh() }
}

struct PreferencesView: View {
    @ObservedObject var model: PreferencesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.title2).bold()
            Toggle(isOn: Binding(
                get: { !model.globallyPaused },
                set: { _ in model.toggleGlobalPause() }
            )) {
                Text("Modules Enabled")
            }
            .toggleStyle(.switch)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Modules").font(.headline)
                ForEach(Array(model.modules.enumerated()), id: \.offset) { idx, m in
                    HStack {
                        Toggle(isOn: Binding(get: { ModuleRegistry.shared.isEnabled(m) }, set: { _ in model.toggle(module: m) })) {
                            Text(m.displayName)
                        }
                        .disabled(model.globallyPaused)
                    }
                }
            }
            Spacer()
            HStack {
                Text(appVersionString())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Close") { closeWindow() }
            }
        }
        .padding(20)
        .frame(width: 400, height: 360)
    }

    private func closeWindow() {
        NSApp.windows.first { $0.identifier?.rawValue == "PreferencesWindow" }?.close()
    }

    private func appVersionString() -> String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "Version \(v)"
    }
}

// Controller to manage showing the preferences window.
final class PreferencesWindowController {
    static let shared = PreferencesWindowController()
    private var window: NSWindow?
    private let model = PreferencesModel()

    func show() {
        if let w = window { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let view = PreferencesView(model: model)
        let hosting = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hosting)
        w.title = "Preferences"
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.isReleasedWhenClosed = false
        w.center()
        w.identifier = NSUserInterfaceItemIdentifier("PreferencesWindow")
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
