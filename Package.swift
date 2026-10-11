// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlobalHotkey",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "GlobalHotkey",
            targets: ["GlobalHotkey"]
        ),
    ],
    targets: [
        .target(
            name: "GlobalHotkey",
            dependencies: [],
            path: "Sources/GlobalHotkey"
        ),
        .testTarget(
            name: "GlobalHotkeyTests",
            dependencies: ["GlobalHotkey"],
            path: "Tests/GlobalHotkeyTests"
        ),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
