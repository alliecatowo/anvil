// swift-tools-version: 6.0
// AnvilUI - main UI package
import PackageDescription

let package = Package(
    name: "AnvilUI",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilUI", targets: ["AnvilUI"]),
    ],
    dependencies: [
        .package(path: "../AnvilDomain"),
        .package(path: "../AnvilApplication"),
        .package(path: "../AnvilACP"),
        .package(path: "../AnvilGit"),
    ],
    targets: [
        .target(
            name: "AnvilUI",
            dependencies: ["AnvilDomain", "AnvilApplication", "AnvilACP", "AnvilGit"],
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilUITests",
            dependencies: ["AnvilUI"],
            path: "Tests"
        ),
    ]
)
