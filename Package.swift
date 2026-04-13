// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StatusBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "StatusBar", targets: ["StatusBarApp"]),
        .library(name: "StatusBarCore", targets: ["StatusBarCore"]),
    ],
    targets: [
        // Platform-agnostic models, protocols, and formatting utilities.
        .target(
            name: "StatusBarCore",
            path: "Sources/StatusBarCore"
        ),
        // macOS menu-bar application that ties everything together.
        .executableTarget(
            name: "StatusBarApp",
            dependencies: ["StatusBarCore"],
            path: "Sources/StatusBarApp"
        ),
        // Unit tests for StatusBarCore (no AppKit dependency).
        .testTarget(
            name: "StatusBarTests",
            dependencies: ["StatusBarCore"],
            path: "Tests/StatusBarTests"
        ),
    ]
)
