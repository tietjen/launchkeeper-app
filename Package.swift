// swift-tools-version:6.0
import PackageDescription
import Foundation

// LaunchKeeperKit comes from the CLI's public repo at a released tag.
// LAUNCHKEEPER_KIT_PATH=../launchkeeper builds against a local checkout
// instead — for changes that land in the kit first.
let kit: Package.Dependency = ProcessInfo.processInfo.environment["LAUNCHKEEPER_KIT_PATH"]
    .map { .package(path: $0) }
    ?? .package(url: "https://github.com/tietjen/launchkeeper", from: "0.12.2")

let package = Package(
    name: "launchkeeper-app",
    defaultLocalization: "de",
    platforms: [.macOS(.v14)],
    products: [
        // Not "LaunchKeeper": the kit's CLI target is "launchkeeper", and on a
        // case-insensitive file system both would share one .build directory
        // (their output-file-maps overwrote each other — CI, 2026-09-26).
        // build-app.sh installs the binary as Contents/MacOS/LaunchKeeper.
        .executable(name: "LaunchKeeperGUI", targets: ["LaunchKeeperGUI"]),
        .executable(name: "LaunchKeeperHelper", targets: ["LaunchKeeperHelper"]),
    ],
    dependencies: [
        kit,
        // In-app updates (Phase 8): EdDSA-signed DMGs from the GitHub releases feed.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        // UI-free logic: loading, filtering, counting — tested without a window.
        .target(
            name: "AppCore",
            dependencies: ["HelperShared", .product(name: "LaunchKeeperKit", package: "launchkeeper")],
            path: "Sources/AppCore"
        ),
        .executableTarget(
            name: "LaunchKeeperGUI",
            dependencies: ["AppCore", "HelperShared", .product(name: "LaunchKeeperKit", package: "launchkeeper"),
                           .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/App",
            resources: [.process("Resources")]
        ),
        // What app and privileged helper must agree on — no dependencies.
        .target(name: "HelperShared", path: "Sources/HelperShared"),
        // The helper's logic, testable without a daemon: root runner, executor.
        .target(
            name: "HelperCore",
            dependencies: ["HelperShared", .product(name: "LaunchKeeperKit", package: "launchkeeper")],
            path: "Sources/HelperCore"
        ),
        // The privileged helper daemon (SMAppService). Its Info.plist is
        // embedded in __TEXT,__info_plist so the binary carries its identity.
        .executableTarget(
            name: "LaunchKeeperHelper",
            dependencies: ["HelperCore", "HelperShared", .product(name: "LaunchKeeperKit", package: "launchkeeper")],
            path: "Sources/Helper",
            exclude: ["Info.plist"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                                           "-Xlinker", "Sources/Helper/Info.plist"])]
        ),
        .testTarget(
            name: "HelperCoreTests",
            dependencies: ["HelperCore", "HelperShared", .product(name: "LaunchKeeperKit", package: "launchkeeper")],
            path: "Tests/HelperCoreTests"
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore", "HelperShared", .product(name: "LaunchKeeperKit", package: "launchkeeper")],
            path: "Tests/AppCoreTests"
        ),
    ]
)
