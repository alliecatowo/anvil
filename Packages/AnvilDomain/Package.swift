// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AnvilDomain",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AnvilDomain", targets: ["AnvilDomain"]),
    ],
    targets: [
        .target(
            name: "AnvilDomain",
            path: "Sources"
        ),
        .testTarget(
            name: "AnvilDomainTests",
            dependencies: ["AnvilDomain"],
            path: "Tests"
        ),
    ]
)
