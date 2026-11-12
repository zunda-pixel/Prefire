import Foundation
import PackagePlugin

/// The build command that generates the tests. SwiftPM runs a tool built from source only in a build
/// command, which declares its output files before the tool runs. They are worked out here, and `prefire` is
/// passed what they follow from with `--plugin-run`: the sources, the variables and whether the snapshots are
/// grouped. It writes only those files then, and stops with an error rather than write another.
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
        let isGrouped = config?.value(of: "use_grouped_snapshots", in: section, environment: environment).map { $0 == "true" } ?? true
        let outputs = outputFiles(sources: sources, isGrouped: isGrouped, outputDirectory: outputDirectory)
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
                arguments: arguments
                    + ["--plugin-run", "--plugin-grouped-snapshots", "\(isGrouped)"]
                    + environment.sorted { $0.key < $1.key }.flatMap { ["--plugin-variable", "\($0.key)=\($0.value)"] }
                    + sources.map(\.path),
                inputFiles: inputs,
                outputFiles: outputs
            ),
        ]
    }

    /// The files `prefire tests` writes: one with every preview, or with `use_grouped_snapshots: false` one per
    /// source. It writes a comment into a declared file it has no enabled previews for, so the files only depend
    /// on the list of sources.
    static func outputFiles(sources: [URL], isGrouped: Bool, outputDirectory: URL) -> [URL] {
        guard !sources.isEmpty else { return [] }

        if isGrouped {
            return [outputDirectory.appending(path: groupedFileName)]
        }

        let names = Set(sources.map { $0.deletingPathExtension().lastPathComponent })
        return names.sorted().map { outputDirectory.appending(path: "\($0)Tests.generated.swift") }
    }
}
