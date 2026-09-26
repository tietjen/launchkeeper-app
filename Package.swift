// swift-tools-version:6.0
import PackageDescription
import Foundation

// LaunchKeeperKit comes from the CLI's public repo at a released tag.
// LAUNCHKEEPER_KIT_PATH=../launchkeeper builds against a local checkout
// instead — for changes that land in the kit first.
let kit: Package.Dependency = ProcessInfo.processInfo.environment["LAUNCHKEEPER_KIT_PATH"]
    .map { .package(path: $0) }
    ?? .package(url: "https://github.com/tietjen/launchkeeper", from: "0.9.5")

let package = Package(
    name: "launchkeeper-app",
    defaultLocalization: "de",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LaunchKeeper", targets: ["LaunchKeeper"]),
    ],
    dependencies: [kit],
    targets: [
        // UI-free logic: loading, filtering, counting — tested without a window.
        .target(
            name: "AppCore",
            dependencies: [.product(name: "LaunchKeeperKit", package: "launchkeeper")],
            path: "Sources/AppCore"
        ),
        .executableTarget(
            name: "LaunchKeeper",
            dependencies: ["AppCore", .product(name: "LaunchKeeperKit", package: "launchkeeper")],
            path: "Sources/App",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore", .product(name: "LaunchKeeperKit", package: "launchkeeper")],
            path: "Tests/AppCoreTests"
        ),
    ]
)
