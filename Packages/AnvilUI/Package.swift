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
        .package(path: "../AnvilGitHub"),
        .package(path: "../AnvilTerminal"),
        .package(path: "../AnvilEditor"),
        .package(url: "https://github.com/CodeEditApp/CodeEditSourceEditor.git", from: "0.15.0"),
        .package(url: "https://github.com/CodeEditApp/CodeEditLanguages.git", from: "0.1.20"),
    ],
    targets: [
        .target(
            name: "AnvilUI",
            dependencies: [
                "AnvilDomain",
                "AnvilApplication",
                "AnvilACP",
                "AnvilGit",
                "AnvilGitHub",
                "AnvilTerminal",
                "AnvilEditor",
                .product(name: "CodeEditSourceEditor", package: "CodeEditSourceEditor"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilUITests",
            dependencies: ["AnvilUI"],
            path: "Tests"
        ),
    ]
)
