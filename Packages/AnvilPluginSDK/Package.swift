// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnvilPluginSDK",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilPluginSDK", targets: ["AnvilPluginSDK"]),
    ],
    dependencies: [
        .package(path: "../AnvilDomain"),
    ],
    targets: [
        .target(
            name: "AnvilPluginSDK",
            dependencies: ["AnvilDomain"],
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilPluginSDKTests",
            dependencies: ["AnvilPluginSDK"],
            path: "Tests"
        ),
    ]
)
