import XCTest
import Foundation
import PathKit
@testable import PrefireCore

final class PrefireCacheManagerTests: XCTestCase {
    private var directory: Path!

    override func setUpWithError() throws {
        directory = Path(NSTemporaryDirectory()) + "PrefireCacheManagerTests-\(UUID().uuidString)"
        try directory.mkpath()
    }

    override func tearDownWithError() throws {
        try? directory.delete()
    }

    private func parse(_ path: Path, defaultEnabled: Bool = true) throws -> ParsedSource {
        let content = try path.read(.utf8)
        return ParsedSource(
            types: TypeScanner.scan(contents: content),
            previews: PreviewLoader.previewModels(from: content, filename: path.lastComponent, defaultEnabled: defaultEnabled) ?? [:]
        )
    }

    func testParsesOnlyTheFilesThatChanged() throws {
        let first = directory + "First.swift"
        let second = directory + "Second.swift"
        try first.write("struct First {}\n#Preview {\n    Text(\"First\")\n}\n")
        try second.write("struct Second {}\n#Preview {\n    Text(\"Second\")\n}\n")
        let manager = PrefireCacheManager(version: "test-1", cacheBasePath: directory + "Cache")

        var parsed: [String] = []
        func load() throws -> (types: [ParsedType], previews: [String: RawPreviewModel]) {
            try manager.load(sources: [first, second], defaultEnabled: true) { path in
                parsed.append(path.lastComponent)
                return try parse(path)
            }
        }

        let initial = try load()
        XCTAssertEqual(parsed, ["First.swift", "Second.swift"])
        XCTAssertEqual(initial.types.map(\.name), ["First", "Second"])
        XCTAssertEqual(initial.previews["First.swift_0"]?.body, "Text(\"First\")")

        parsed = []
        let cached = try load()
        XCTAssertEqual(parsed, [])
        XCTAssertEqual(cached.types, initial.types)
        XCTAssertEqual(cached.previews, initial.previews)

        try second.write("struct Second {}\n#Preview {\n    Text(\"Changed\")\n}\n")
        parsed = []
        let updated = try load()
        XCTAssertEqual(parsed, ["Second.swift"])
        XCTAssertEqual(updated.previews["First.swift_0"]?.body, "Text(\"First\")")
        XCTAssertEqual(updated.previews["Second.swift_0"]?.body, "Text(\"Changed\")")
    }

    func testParsesAgainWithAnotherDefaultEnabled() throws {
        let file = directory + "Example.swift"
        try file.write("#Preview {\n    Text(\"Hello\")\n}\n")
        let manager = PrefireCacheManager(version: "test-1", cacheBasePath: directory + "Cache")

        let enabled = try manager.load(sources: [file], defaultEnabled: true) { try parse($0, defaultEnabled: true) }
        var parsedAgain = false
        let disabled = try manager.load(sources: [file], defaultEnabled: false) { path in
            parsedAgain = true
            return try parse(path, defaultEnabled: false)
        }

        XCTAssertTrue(parsedAgain)
        XCTAssertEqual(enabled.previews.count, 1)
        XCTAssertEqual(disabled.previews.count, 0)
    }

    func testParsesAgainWhenTheFileOfASymbolicLinkChanges() throws {
        let file = directory + "Real.swift"
        let link = directory + "Link.swift"
        try file.write("#Preview {\n    Text(\"Old\")\n}\n")
        try FileManager.default.createSymbolicLink(atPath: link.string, withDestinationPath: file.string)
        let manager = PrefireCacheManager(version: "test-1", cacheBasePath: directory + "Cache")

        _ = try manager.load(sources: [link], defaultEnabled: true) { try parse($0) }
        try file.write("#Preview {\n    Text(\"Changed preview\")\n}\n")
        let updated = try manager.load(sources: [link], defaultEnabled: true) { try parse($0) }

        XCTAssertEqual(updated.previews["Link.swift_0"]?.body, "Text(\"Changed preview\")")
    }

    func testKeepsTheEntriesOfSourcesNotInThisRun() throws {
        let first = directory + "First.swift"
        let second = directory + "Second.swift"
        try first.write("struct First {}\n")
        try second.write("struct Second {}\n")
        let manager = PrefireCacheManager(version: "test-1", cacheBasePath: directory + "Cache")

        _ = try manager.load(sources: [first, second], defaultEnabled: true) { try parse($0) }
        _ = try manager.load(sources: [first], defaultEnabled: true) { try parse($0) }
        var parsed: [String] = []
        _ = try manager.load(sources: [first, second], defaultEnabled: true) { path in
            parsed.append(path.lastComponent)
            return try parse(path)
        }

        XCTAssertEqual(parsed, [])
    }

    func testSkipsThePreviewsOfASecondFileWithTheSameName() throws {
        let first = directory + "FeatureA" + "Row.swift"
        let second = directory + "FeatureB" + "Row.swift"
        try first.parent().mkpath()
        try second.parent().mkpath()
        try first.write("#Preview {\n    Text(\"A\")\n}\n")
        try second.write("#Preview {\n    Text(\"B\")\n}\n\n#Preview {\n    Text(\"B2\")\n}\n")
        let manager = PrefireCacheManager(version: "test-1", cacheBasePath: directory + "Cache")

        let loaded = try manager.load(sources: [first, second], defaultEnabled: true) { try parse($0) }

        XCTAssertEqual(loaded.previews.mapValues(\.body), ["Row.swift_0": "Text(\"A\")"])
    }
}
