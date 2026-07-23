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
