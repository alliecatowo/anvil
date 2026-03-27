// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Anvil",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Anvil", targets: ["Anvil"]),
    ],
    dependencies: [
        .package(path: "Packages/AnvilDomain"),
        .package(path: "Packages/AnvilApplication"),
        .package(path: "Packages/AnvilACP"),
        .package(path: "Packages/AnvilInfrastructure"),
        .package(path: "Packages/AnvilUI"),
        .package(path: "Packages/AnvilPluginSDK"),
        .package(path: "Packages/AnvilGit"),
    ],
    targets: [
        .executableTarget(
            name: "Anvil",
            dependencies: [
                "AnvilDomain",
                "AnvilApplication",
                "AnvilACP",
                "AnvilInfrastructure",
                "AnvilUI",
                "AnvilPluginSDK",
                "AnvilGit",
            ],
            path: "App"
        ),
    ]
)
