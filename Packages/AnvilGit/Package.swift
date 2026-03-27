// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnvilGit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilGit", targets: ["AnvilGit"]),
    ],
    dependencies: [
        .package(path: "../AnvilDomain"),
    ],
    targets: [
        .target(
            name: "AnvilGit",
            dependencies: ["AnvilDomain"],
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilGitTests",
            dependencies: ["AnvilGit"],
            path: "Tests"
        ),
    ]
)
