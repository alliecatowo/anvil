// swift-tools-version: 6.0
// AnvilEditor - Editor engine with LSP integration
import PackageDescription

let package = Package(
    name: "AnvilEditor",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilEditor", targets: ["AnvilEditor"]),
    ],
    targets: [
        .target(
            name: "AnvilEditor",
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilEditorTests",
            dependencies: ["AnvilEditor"],
            path: "Tests"
        ),
    ]
)
