// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Prefire",
    platforms: [.iOS(.v14), .macOS(.v13), .watchOS(.v7)],
    products: [
        .library(name: "Prefire", targets: ["Prefire"]),
        .library(name: "PrefireVoiceOver", targets: ["PrefireVoiceOver"]),
        .plugin(
            name: "PrefirePlaybookPlugin",
            targets: ["PrefirePlaybookPlugin"]
        ),
        .plugin(
            name: "PrefireTestsPlugin",
            targets: ["PrefireTestsPlugin"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.3"),
        .package(url: "https://github.com/kylef/PathKit.git", from: "1.0.1"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"605.0.0"),
        .package(url: "https://github.com/stencilproject/Stencil.git", from: "0.15.1"),
        .package(url: "https://github.com/SwiftGen/StencilSwiftKit.git", from: "2.10.1"),
    ],
    targets: [
        .target(name: "Prefire"),
        .target(
            name: "PrefireVoiceOver",
            dependencies: ["Prefire"]
        ),
        .target(
            name: "PrefireCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "Stencil", package: "Stencil"),
                .product(name: "StencilSwiftKit", package: "StencilSwiftKit"),
                .product(name: "PathKit", package: "PathKit"),
            ]
        ),
        .executableTarget(
            name: "PrefireTool",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "PrefireCore"),
            ]
        ),
        .testTarget(
            name: "PrefireLibraryTests",
            dependencies: ["Prefire"]
        ),
        .testTarget(
            name: "PrefireTests",
            dependencies: ["PrefireTool"]
        ),
        .plugin(
            name: "PrefirePlaybookPlugin",
            capability: .buildTool(),
            dependencies: ["PrefireTool"]
        ),
        .plugin(
            name: "PrefireTestsPlugin",
            capability: .buildTool(),
            dependencies: ["PrefireTool"]
        ),
    ]
)
