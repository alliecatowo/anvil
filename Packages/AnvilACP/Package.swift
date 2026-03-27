// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnvilACP",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilACP", targets: ["AnvilACP"]),
    ],
    dependencies: [
        .package(path: "../AnvilDomain"),
    ],
    targets: [
        .target(
            name: "AnvilACP",
            dependencies: ["AnvilDomain"],
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilACPTests",
            dependencies: ["AnvilACP"],
            path: "Tests"
        ),
    ]
)
