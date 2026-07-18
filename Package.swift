// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BarEverything",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BarEverything", targets: ["BarEverything"]),
    ],
    targets: [
        .executableTarget(name: "BarEverything"),
        .testTarget(name: "BarEverythingTests", dependencies: ["BarEverything"]),
    ]
)
