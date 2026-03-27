// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnvilApplication",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilApplication", targets: ["AnvilApplication"]),
    ],
    dependencies: [
        .package(path: "../AnvilDomain"),
    ],
    targets: [
        .target(
            name: "AnvilApplication",
            dependencies: ["AnvilDomain"],
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilApplicationTests",
            dependencies: ["AnvilApplication"],
            path: "Tests"
        ),
    ]
)
