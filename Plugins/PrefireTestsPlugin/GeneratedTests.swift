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
        let sources = config?.sourceFiles(in: section, environment: environment) ?? targetSources
        let outputs = outputFiles(sources: sources, config: config, environment: environment, outputDirectory: outputDirectory)
        guard !outputs.isEmpty else { return [] }

        var inputs = sources
        if let config {
            inputs.append(config.url)
            let template = config.template(in: section, baseKey: "test_target_path", defaultBase: testTargetDirectory, environment: environment)
            inputs += template.map { [$0] } ?? []
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
    /// source. It writes a comment into a declared file it has no enabled previews for, so the files only depend
    /// on the list of sources.
    static func outputFiles(sources: [URL], config: PrefireConfigFile?, environment: [String: String], outputDirectory: URL) -> [URL] {
        guard !sources.isEmpty else { return [] }

        let isGrouped = config?.value(of: "use_grouped_snapshots", in: section, environment: environment).map { $0 == "true" } ?? true
        if isGrouped {
            return [outputDirectory.appending(path: groupedFileName)]
        }

        let names = Set(sources.map { $0.deletingPathExtension().lastPathComponent })
        return names.sorted().map { outputDirectory.appending(path: "\($0)Tests.generated.swift") }
    }
}
