// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnvilGitHub",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilGitHub", targets: ["AnvilGitHub"]),
    ],
    dependencies: [
        .package(path: "../AnvilDomain"),
    ],
    targets: [
        .target(
            name: "AnvilGitHub",
            dependencies: ["AnvilDomain"],
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilGitHubTests",
            dependencies: ["AnvilGitHub"],
            path: "Tests"
        ),
    ]
)
