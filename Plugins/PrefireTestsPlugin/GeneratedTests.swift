import Foundation
import PackagePlugin

/// The build command that generates the tests. SwiftPM runs a tool built from source only in a build
/// command, which declares its output files before the tool runs. They are worked out here and passed to
/// `prefire` with `--declared-output`: it writes only those, and stops with an error rather than write another.
enum GeneratedTests {
    private static let section = "test_configuration"
    private static let groupedFileName = "PreviewTests.generated.swift"

    static func commands(
        tool: URL,
        arguments: [String],
        environment: [String: String],
        sources targetSources: [URL],
        config: PrefireConfigFile?,
        testTargetDirectory: URL,
        outputDirectory: URL
    ) -> [Command] {
        let targetSources = targetSources.filter { $0.pathExtension == "swift" }
        // `prefire` reads the files of `sources` in `.prefire.yml` instead of the target's.
        let sources = config?.values(of: "sources", in: section, environment: environment).map(swiftFiles(at:)) ?? targetSources
        let outputs = outputFiles(sources: sources, config: config, environment: environment, outputDirectory: outputDirectory)
        guard !outputs.isEmpty else { return [] }

        var inputs = sources
        if let config {
            inputs.append(config.url)
            if let template = config.value(of: "template_file_path", in: section, environment: environment) {
                // `prefire` resolves it from `test_target_path`, or else from the test target.
                let base = config.value(of: "test_target_path", in: section, environment: environment).map { URL(filePath: $0) }
                let url = (base ?? testTargetDirectory).appending(path: template)
                if FileManager.default.fileExists(atPath: url.path) { inputs.append(url) }
            }
        }

        return [
            .buildCommand(
                displayName: "Running Prefire",
                executable: tool,
                arguments: arguments + outputs.flatMap { ["--declared-output", $0.path] } + targetSources.map(\.path),
                environment: environment,
                inputFiles: inputs,
                outputFiles: outputs
            ),
        ]
    }

    /// The files `prefire tests` writes: one with every preview, or with `use_grouped_snapshots: false` one per
    /// source containing `#Preview`. It writes a comment into a declared file it has no enabled previews for.
    static func outputFiles(sources: [URL], config: PrefireConfigFile?, environment: [String: String], outputDirectory: URL) -> [URL] {
        guard !sources.isEmpty else { return [] }

        let isGrouped = config?.value(of: "use_grouped_snapshots", in: section, environment: environment).map { $0 == "true" } ?? true
        if isGrouped {
            return [outputDirectory.appending(path: groupedFileName)]
        }

        let names = Set(sources.filter { source in
            (try? String(contentsOf: source, encoding: .utf8))?.contains("#Preview") == true
        }.map { $0.deletingPathExtension().lastPathComponent })

        return names.sorted().map { outputDirectory.appending(path: "\($0)Tests.generated.swift") }
    }

    /// The Swift files at `paths`, files or directories searched recursively, as `prefire` finds them.
    private static func swiftFiles(at paths: [String]) -> [URL] {
        var files: Set<URL> = []
        for path in paths {
            let url = URL(filePath: path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)
                while let file = enumerator?.nextObject() as? URL {
                    if file.pathExtension == "swift" { files.insert(file) }
                }
            } else if url.pathExtension == "swift" {
                files.insert(url)
            }
        }
        return files.sorted { $0.path < $1.path }
    }
}
