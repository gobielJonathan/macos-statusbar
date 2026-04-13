// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacOSBar",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "MacOSBar",
            targets: ["MacOSBar"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "MacOSBar",
            path: "Sources/MacOSBarApp",
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
