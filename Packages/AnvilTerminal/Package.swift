// swift-tools-version: 6.0
// AnvilTerminal - Real PTY terminal engine powered by SwiftTerm
import PackageDescription

let package = Package(
    name: "AnvilTerminal",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilTerminal", targets: ["AnvilTerminal"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.19.0"),
    ],
    targets: [
        .target(
            name: "AnvilTerminal",
            dependencies: ["SwiftTerm"],
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilTerminalTests",
            dependencies: ["AnvilTerminal"],
            path: "Tests"
        ),
    ]
)
