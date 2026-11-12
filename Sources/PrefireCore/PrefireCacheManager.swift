import Foundation
import CryptoKit
import PathKit

/// The types and previews of one source file.
struct ParsedSource: Codable, Equatable {
    var types: [ParsedType]
    var previews: [String: RawPreviewModel]
}

/// Keeps what each source file parsed to, so a run parses only the files that changed since the last one.
struct PrefireCacheManager {
    private let version: String
    private let cacheBasePath: Path?

    init(version: String, cacheBasePath: Path? = nil) {
        self.version = version
        self.cacheBasePath = cacheBasePath
    }

    /// The types and previews of `sources`, merged in their order. `parse` runs for the files that aren't in
    /// the cache, or that changed or were parsed with another `defaultEnabled` since.
    func load(
        sources: [Path],
        defaultEnabled: Bool,
        parse: (Path) throws -> ParsedSource
    ) throws -> (types: [ParsedType], previews: [String: RawPreviewModel]) {
        let dir = Path.cachesDir(sourcePath: sources.first ?? .current, basePath: cacheBasePath)
        let cacheFile = dir + "\(version)-sources.json"

        var cached: [String: CacheEntry] = [:]
        if cacheFile.exists {
            do {
                cached = try JSONDecoder().decode([String: CacheEntry].self, from: Data(contentsOf: cacheFile.url))
            } catch {
                Logger.warning("⚠️ Failed to read the parse cache: \(error)")
            }
        }

        var entries: [String: CacheEntry] = [:]
        var parsedSources: [ParsedSource] = []
        var parsedCount = 0
        for source in sources {
            let stamp = FileStamp(source)
            if let entry = cached[source.string], entry.stamp == stamp, entry.defaultEnabled == defaultEnabled {
                entries[source.string] = entry
                parsedSources.append(entry.source)
            } else {
                let parsed = try parse(source)
                entries[source.string] = CacheEntry(stamp: stamp, defaultEnabled: defaultEnabled, source: parsed)
                parsedSources.append(parsed)
                parsedCount += 1
            }
        }
        Logger.info("🧩 Parsed \(parsedCount) of \(sources.count) Swift files, the others came from the cache.")

        if parsedCount > 0 || entries.count != cached.count {
            try dir.mkpath()
            try JSONEncoder().encode(entries).write(to: cacheFile.url, options: .atomic)
        }

        var previews: [String: RawPreviewModel] = [:]
        for source in parsedSources {
            previews.merge(source.previews) { current, _ in current }
        }
        return (TypeScanner.merge(parsedSources.map(\.types)), previews)
    }
}

private struct CacheEntry: Codable {
    var stamp: FileStamp
    var defaultEnabled: Bool
    var source: ParsedSource
}

/// When a file was last changed, and its size.
private struct FileStamp: Codable, Equatable {
    var modificationDate: Double?
    var size: UInt64?

    init(_ path: Path) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path.string)
        modificationDate = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970
        size = (attributes?[.size] as? NSNumber)?.uint64Value
    }
}

// MARK: - Extensions

private extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

extension Path {
    /// User caches directory, the root Prefire writes its parse cache into.
    static var defaultBaseCachePath: Path {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return Path(paths[0])
    }

    static func cachesDir(
        sourcePath: Path,
        basePath: Path? = nil,
        createIfMissing: Bool = true
    ) -> Path {
        let root = (basePath ?? defaultBaseCachePath) + "PrefireCache"
        let dir = root + sourcePath.absolute().sha256prefix(8)
        if createIfMissing, !dir.exists { try? dir.mkpath() }
        return dir
    }

    fileprivate func sha256prefix(_ length: Int) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.hexString.prefix(length).description
    }
}
