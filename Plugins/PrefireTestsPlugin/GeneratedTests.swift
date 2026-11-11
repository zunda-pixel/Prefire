import Foundation
import PackagePlugin

/// The build command that generates the tests. SwiftPM runs a tool built from source only in a build
/// command, which declares its output files before the tool runs, so they are worked out here.
enum GeneratedTests {
    private static let section = "test_configuration"
    private static let groupedFileName = "PreviewTests.generated.swift"

    static func commands(
        tool: URL,
        arguments: [String],
        environment: [String: String],
        sources: [URL],
        config: PrefireConfigFile?,
        testTargetDirectory: URL,
        outputDirectory: URL
    ) throws -> [Command] {
        let sources = sources.filter { $0.pathExtension == "swift" }
        let outputs = try outputFiles(sources: sources, config: config, outputDirectory: outputDirectory)
        guard !outputs.isEmpty else { return [] }

        var inputs = sources
        if let config {
            inputs.append(config.url)
            if let template = config.value(of: "template_file_path", in: section) {
                let url = testTargetDirectory.appending(path: template)
                if FileManager.default.fileExists(atPath: url.path) { inputs.append(url) }
            }
        }

        return [
            .buildCommand(
                displayName: "Running Prefire",
                executable: tool,
                arguments: arguments + ["--file-per-preview-source"] + sources.map(\.path),
                environment: environment,
                inputFiles: inputs,
                outputFiles: outputs
            ),
        ]
    }

    /// The files `prefire tests --file-per-preview-source` writes: one with every preview, or with
    /// `use_grouped_snapshots: false` one per source containing `#Preview`.
    static func outputFiles(sources: [URL], config: PrefireConfigFile?, outputDirectory: URL) throws -> [URL] {
        if config?.value(of: "test_file_path", in: section) != nil {
            throw "❌ Prefire error: `test_file_path` isn't supported by PrefireTestsPlugin, which generates the tests into its work directory. Remove it from `.prefire.yml`, or generate the tests with the `prefire` CLI."
        }
        guard !sources.isEmpty else { return [] }

        let isGrouped = config?.value(of: "use_grouped_snapshots", in: section).map { $0 == "true" } ?? true
        if isGrouped {
            return [outputDirectory.appending(path: groupedFileName)]
        }

        if config?.value(of: "sources", in: section) != nil {
            throw "❌ Prefire error: `sources` together with `use_grouped_snapshots: false` isn't supported by PrefireTestsPlugin, which has to know the generated files before it runs. Remove one of them from `.prefire.yml`, or generate the tests with the `prefire` CLI."
        }

        let names = Set(sources.filter { source in
            (try? String(contentsOf: source, encoding: .utf8))?.contains("#Preview") == true
        }.map { $0.deletingPathExtension().lastPathComponent })

        return names.sorted().map { outputDirectory.appending(path: "\($0)Tests.generated.swift") }
    }
}
