// swift-tools-version: 6.0
// TuringOS.app sovereign-host shell (ADR-005: pure projection consumer).
// SwiftPM is the project format: `swift build`/`swift test` run headless in
// CI, Xcode opens this file directly for development, and the .app bundle
// is assembled by scripts/build_app.sh - no hand-maintained pbxproj.
import PackageDescription

let package = Package(
    name: "TuringOS",
    platforms: [
        // ADR-008: deployment target macOS 26; built locally with the
        // Xcode 27 SDK (DEVELOPER_DIR), on CI with the runner's 26.5.
        .macOS("26.0")
    ],
    targets: [
        .executableTarget(
            name: "TuringOS",
            path: "Sources/TuringOS",
            resources: [.copy("Resources/Fonts")]
        ),
        .testTarget(
            name: "TuringOSTests",
            dependencies: ["TuringOS"],
            path: "Tests/TuringOSTests"
        ),
    ]
)
