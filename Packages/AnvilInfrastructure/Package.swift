// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnvilInfrastructure",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilInfrastructure", targets: ["AnvilInfrastructure"]),
    ],
    dependencies: [
        .package(path: "../AnvilDomain"),
        .package(path: "../AnvilApplication"),
        .package(path: "../AnvilACP"),
    ],
    targets: [
        .target(
            name: "AnvilInfrastructure",
            dependencies: ["AnvilDomain", "AnvilApplication", "AnvilACP"],
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilInfrastructureTests",
            dependencies: ["AnvilInfrastructure"],
            path: "Tests"
        ),
    ]
)
