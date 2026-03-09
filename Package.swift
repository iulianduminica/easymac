// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EasyMac",
    platforms: [ .macOS(.v13) ],
    products: [
        .executable(name: "EasyMac", targets: ["EasyMac"])
    ],
    targets: [
        .executableTarget(
            name: "EasyMac",
            path: ".",
            exclude: ["build", "scripts", "Docs", "todo.md", "app_development_standards.md"],
            sources: [
                "main.swift",
                "Preferences.swift",
                "Modules/Constants.swift",
                "Modules/CutPasteModule.swift",
                "Modules/DockClickModule.swift",
                "Modules/EventRouter.swift",
                "Modules/ModuleProtocol.swift",
                "Modules/ModuleRegistry.swift",
                "Modules/PureUtilities.swift",
                "Modules/SharedUtilities.swift",
                "Modules/TrashKeyModule.swift",
                "Modules/UsageStats.swift"
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
