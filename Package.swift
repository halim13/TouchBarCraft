// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "touchbar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "touchbar",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
    ]
)
