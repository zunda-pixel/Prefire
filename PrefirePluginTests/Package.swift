// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// A macOS package that applies both plugins, so `swift build` builds the generator from source and checks
/// the files the plugins declare: `.prefire.yml` asks for one test file per source, and the sources cover
/// an enabled preview, a source whose previews are all ignored, and `#Preview` only in a comment.
/// Run it with `make test-plugins`.
let package = Package(
    name: "PrefirePluginTests",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "Prefire", path: "../"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "Previews",
            dependencies: [
                .product(name: "Prefire", package: "Prefire"),
            ],
            plugins: [
                .plugin(name: "PrefirePlaybookPlugin", package: "Prefire"),
            ]
        ),
        .testTarget(
            name: "PreviewsTests",
            dependencies: [
                "Previews",
                .product(name: "Prefire", package: "Prefire"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            plugins: [
                .plugin(name: "PrefireTestsPlugin", package: "Prefire"),
            ]
        ),
    ]
)
