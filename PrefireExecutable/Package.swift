// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// The root Package.swift builds these sources too, for the plugins and the `prefire` product.
// Keep the dependencies of both manifests in step.
let package = Package(
    name: "PrefireExecutable",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "prefire",
            targets: ["prefire"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.2.3")),
        .package(url: "https://github.com/kylef/PathKit.git", .upToNextMinor(from: "1.0.1")),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", .upToNextMinor(from: "600.0.0")),
        .package(url: "https://github.com/stencilproject/Stencil.git", from: "0.15.1"),
        .package(url: "https://github.com/SwiftGen/StencilSwiftKit.git", from: "2.10.1"),
    ],
    targets: [
        .target(
            name: "PrefireCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "Stencil", package: "Stencil"),
                .product(name: "StencilSwiftKit", package: "StencilSwiftKit"),
                "PathKit"
            ]
        ),
        .target(
            name: "PrefireCommands",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "PrefireCore",
                "PathKit",
            ]
        ),
        .executableTarget(
            name: "prefire",
            dependencies: ["PrefireCommands"]
        ),
        .testTarget(
            name: "PrefireTests",
            dependencies: ["PrefireCommands"]
        ),
    ]
)
