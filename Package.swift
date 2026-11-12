// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Prefire",
    platforms: [.iOS(.v14), .macOS(.v13), .watchOS(.v7)],
    products: [
        .library(name: "PrefireVoiceOver", targets: ["PrefireVoiceOver"]),
        .library(
            name: "Prefire",
            targets: ["Prefire"]
        ),
        .plugin(
            name: "PrefirePlaybookPlugin",
            targets: ["PrefirePlaybookPlugin"]
        ),
        .plugin(
            name: "PrefireTestsPlugin",
            targets: ["PrefireTestsPlugin"]
        ),
    ],
    // The generator of PrefireExecutable, built from source for the plugins.
    // Keep these in step with PrefireExecutable/Package.swift, with ranges wide enough for the packages
    // they meet in an app.
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.3"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "1.0.1"),
        // A major version of swift-syntax per Swift release; PrefireCore builds with 600 to 604.
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"605.0.0"),
        .package(url: "https://github.com/stencilproject/Stencil.git", from: "0.15.1"),
        .package(url: "https://github.com/SwiftGen/StencilSwiftKit.git", from: "2.10.1"),
    ],
    targets: [
        .target(
            name: "PrefireVoiceOver",
            dependencies: ["Prefire"]
        ),
        .target(
            name: "Prefire",
            dependencies: []
        ),
        .target(
            name: "PrefireCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "Stencil", package: "Stencil"),
                .product(name: "StencilSwiftKit", package: "StencilSwiftKit"),
                "PathKit",
            ],
            path: "PrefireExecutable/Sources/PrefireCore"
        ),
        .target(
            name: "PrefireCommands",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "PrefireCore",
                "PathKit",
            ],
            path: "PrefireExecutable/Sources/PrefireCommands"
        ),
        // `prefire`, which the plugins build and run. No product: Xcode builds an executable product under
        // the product's name, but looks a plugin tool up by the target's name. Not named `prefire`, which
        // clashes with the `Prefire` module on case-insensitive disks.
        .executableTarget(
            name: "PrefireTool",
            dependencies: ["PrefireCommands"]
        ),
        .testTarget(
            name: "PrefireCLITests",
            dependencies: ["Prefire"]
        ),
        .plugin(
            name: "PrefirePlaybookPlugin",
            capability: .buildTool(),
            dependencies: [
                "PrefireTool",
            ]
        ),
        .plugin(
            name: "PrefireTestsPlugin",
            capability: .buildTool(),
            dependencies: [
                "PrefireTool",
            ]
        ),
    ]
)
