// swift-tools-version: 6.0
// AnvilEditor - Editor engine with LSP integration
import PackageDescription

let package = Package(
    name: "AnvilEditor",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilEditor", targets: ["AnvilEditor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CodeEditApp/CodeEditSourceEditor.git", from: "0.15.0"),
        .package(url: "https://github.com/CodeEditApp/CodeEditLanguages.git", from: "0.1.20"),
    ],
    targets: [
        .target(
            name: "AnvilEditor",
            dependencies: [
                .product(name: "CodeEditSourceEditor", package: "CodeEditSourceEditor"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilEditorTests",
            dependencies: ["AnvilEditor"],
            path: "Tests"
        ),
    ]
)
