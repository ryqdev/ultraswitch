// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UltraSwitch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "UltraSwitch",
            path: "Sources/UltraSwitch",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
            ]
        )
    ]
)
