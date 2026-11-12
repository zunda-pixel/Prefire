#if os(macOS)
@preconcurrency import ArgumentParser
import Foundation
import PrefireCore

extension Prefire {
    struct Tests: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Generate Snapshot/Accessibility Tests")

        @Argument(help: "Paths to a source swift files or directories.")
        var sources: [String] = [FileManager.default.currentDirectoryPath]

        @Option(help: "Path to your custom template.")
        var template: String?

        @Option(help: "Your project Target tested by snapshots.")
        var target: String?
        @Option(help: "Your Snapshot Tests Target.")
        var testTarget: String?

        @Option(help: "Path to a config `.prefire.yml`.")
        var config: String?
        @Option(help: "Path to generated file.")
        var output: String?
        @Option(help: "Path to your Snapshot Tests Target.")
        var testTargetPath: String?
        @Option(help: "Base path to the cache directory.")
        var cacheBasePath: String?
        @Option(help: "Required Device for Snapshot testing.")
        var device: String?
        @Option(help: "Required OS version for Snapshot testing.")
        var osVersion: String?

        @Flag(help: "Display full info")
        var verbose = false

        @Flag(name: .customLong("plugin-run"), help: ArgumentHelp("Run by a build tool plugin.", visibility: .hidden))
        var isPluginRun = false
        @Option(help: ArgumentHelp("A variable the plugin replaced in `.prefire.yml`, as NAME=VALUE.", visibility: .hidden))
        var pluginVariable: [String] = []
        @Option(help: ArgumentHelp("Whether the plugin declared one file with every preview.", visibility: .hidden))
        var pluginGroupedSnapshots: Bool?

        func run() async throws {
            Logger.level = verbose ? .verbose : .warnings
            let pluginRun = try PluginRun(isPluginRun: isPluginRun, variables: pluginVariable, groupedSnapshots: pluginGroupedSnapshots)
            let config = Config.load(
                from: config,
                testTargetPath: testTargetPath,
                env: PluginRun.environment(for: pluginRun),
                includeCurrentDirectory: pluginRun == nil
            )

            try await GenerateTestsCommand.run(
                GeneratedTestsOptions(
                    target: target,
                    testTarget: testTarget,
                    template: template,
                    sources: sources,
                    output: output,
                    testTargetPath: testTargetPath,
                    cacheBasePath: cacheBasePath,
                    device: device,
                    osVersion: osVersion,
                    config: config,
                    pluginRun: pluginRun
                )
            )
        }
    }
}
#endif
