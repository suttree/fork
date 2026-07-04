// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Fork",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ForkCore", targets: ["ForkCore"]),
        .executable(name: "ForkApp", targets: ["ForkApp"])
    ],
    targets: [
        .target(name: "ForkCore"),
        .executableTarget(
            name: "ForkApp",
            dependencies: ["ForkCore"]
        ),
        .testTarget(
            name: "ForkCoreTests",
            dependencies: ["ForkCore"]
        )
    ]
)
