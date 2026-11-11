import Foundation
import PackagePlugin

@main
struct PrefirePlaybookPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let executable = try context.tool(named: "PrefireTool").url

        let cachePath = context.pluginWorkDirectoryURL.appending(path: "Cache")
        let outputPath = context.pluginWorkDirectoryURL.appending(path: "Generated")
        let targetPath = String(describing: target.directory)

        let arguments: [String] = [
            "playbook",
            "--output", outputPath.path,
            "--target-path", targetPath,
            "--config", targetPath,
            "--cache-base-path", cachePath.path,
            "--verbose",
        ]

        let sources = (target as? SwiftSourceModuleTarget)?.sourceFiles.filter { $0.type == .source }.map(\.url) ?? []

        // Where `prefire` looks for `.prefire.yml`: `--config`, then `PACKAGE_DIR`.
        let targetURL = URL(filePath: targetPath)
        let config = PrefireConfigFile.first(in: [targetURL, context.package.directoryURL])

        return GeneratedPlaybook.commands(
            tool: executable,
            arguments: arguments,
            sources: sources,
            config: config,
            targetDirectory: targetURL,
            outputDirectory: outputPath
        )
    }
}

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension PrefirePlaybookPlugin: XcodeBuildToolPlugin {
        func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
            let executable = try context.tool(named: "PrefireTool").url

            let cachePath = context.pluginWorkDirectoryURL.appending(path: "Cache")
            let outputPath = context.pluginWorkDirectoryURL.appending(path: "Generated")
            let targetPath = context.xcodeProject.directoryURL.appending(path: target.displayName)

            let arguments: [String] = [
                "playbook",
                "--output", outputPath.path,
                "--target-path", targetPath.path,
                "--config", context.xcodeProject.directoryURL.path,
                "--cache-base-path", cachePath.path,
                "--verbose",
            ]

            // Where `prefire` looks for `.prefire.yml`: `--config`.
            let config = PrefireConfigFile.first(in: [context.xcodeProject.directoryURL])

            return GeneratedPlaybook.commands(
                tool: executable,
                arguments: arguments,
                sources: target.inputFiles.filter { $0.type == .source }.map { $0.url },
                config: config,
                targetDirectory: targetPath,
                outputDirectory: outputPath
            )
        }
    }
#endif

/// The build command that generates the Playbook models. SwiftPM runs a tool built from source only in a
/// build command, which declares its output files before the tool runs: here always one file.
enum GeneratedPlaybook {
    static func commands(
        tool: URL,
        arguments: [String],
        sources: [URL],
        config: PrefireConfigFile?,
        targetDirectory: URL,
        outputDirectory: URL
    ) -> [Command] {
        let sources = sources.filter { $0.pathExtension == "swift" }
        guard !sources.isEmpty else { return [] }

        var inputs = sources
        if let config {
            inputs.append(config.url)
            if let template = config.value(of: "template_file_path", in: "playbook_configuration") {
                let url = targetDirectory.appending(path: template)
                if FileManager.default.fileExists(atPath: url.path) { inputs.append(url) }
            }
        }

        return [
            .buildCommand(
                displayName: "Running Prefire",
                executable: tool,
                arguments: arguments + sources.map(\.path),
                inputFiles: inputs,
                outputFiles: [outputDirectory.appending(path: "PreviewModels.generated.swift")]
            ),
        ]
    }
}
