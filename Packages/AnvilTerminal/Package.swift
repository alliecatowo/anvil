// swift-tools-version: 6.0
// AnvilTerminal - Real PTY terminal engine
import PackageDescription

let package = Package(
    name: "AnvilTerminal",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilTerminal", targets: ["AnvilTerminal"]),
    ],
    targets: [
        .target(
            name: "AnvilTerminal",
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilTerminalTests",
            dependencies: ["AnvilTerminal"],
            path: "Tests"
        ),
    ]
)
