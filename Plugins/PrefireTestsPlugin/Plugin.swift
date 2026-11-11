import Foundation
import PackagePlugin

@main
struct PrefireTestsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let executable = try context.tool(named: "PrefireTool").url

        let cachePath = context.pluginWorkDirectoryURL.appending(path: "Cache")
        let outputPath = context.pluginWorkDirectoryURL.appending(path: "Generated")

        guard let testedTarget = try TestedTargetFinder.findTestedTarget(for: target) else {
            throw "❌ Prefire error: Cannot find target for testing. Please use `.prefire.yml` and set `target:` field."
        }

        let arguments: [String] = [
            "tests",
            "--target", testedTarget.name,
            "--test-target", target.name,
            "--output", outputPath.path,
            "--test-target-path", String(describing: target.directory),
            "--config", testedTarget.directoryURL.path,
            "--cache-base-path", cachePath.path,
            "--verbose",
        ]

        let environment = [
            "TARGET_DIR": String(describing: target.directory),
            "PACKAGE_DIR": context.package.directoryURL.path(percentEncoded: false),
        ]

        // Where `prefire` looks for `.prefire.yml`: `--test-target-path`, `--config`, then `PACKAGE_DIR`.
        let testTargetURL = URL(filePath: String(describing: target.directory))
        let config = PrefireConfigFile.first(in: [testTargetURL, testedTarget.directoryURL, context.package.directoryURL])

        return try GeneratedTests.commands(
            tool: executable,
            arguments: arguments,
            environment: environment,
            sources: testedTarget.sourceFiles.filter { $0.type == .source }.map(\.url),
            config: config,
            testTargetDirectory: testTargetURL,
            outputDirectory: outputPath
        )
    }
}

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension PrefireTestsPlugin: XcodeBuildToolPlugin {
        func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
            let executable = try context.tool(named: "PrefireTool").url

            let cacheURL = context.pluginWorkDirectoryURL.appending(path: "Cache")
            let outputURL = context.pluginWorkDirectoryURL.appending(path: "Generated")
            let testTargetURL = context.xcodeProject.directoryURL.appending(path: target.displayName)

            guard let testedTarget = try TestedTargetFinder.findTestedTarget(for: target, project: context.xcodeProject) else {
                throw "Prefire cannot find target for testing. Please, use `.prefire.yml` file, for providing `Target Name`"
            }

            let arguments: [String] = [
                "tests",
                "--target", testedTarget.displayName,
                "--test-target", target.displayName,
                "--output", outputURL.path,
                "--test-target-path", testTargetURL.path,
                "--config", context.xcodeProject.directoryURL.path,
                "--cache-base-path", cacheURL.path,
                "--verbose",
            ]

            let environment = [
                "PROJECT_DIR": context.xcodeProject.directoryURL.path(percentEncoded: false),
            ]

            // Where `prefire` looks for `.prefire.yml`: `--test-target-path`, then `--config`.
            let config = PrefireConfigFile.first(in: [testTargetURL, context.xcodeProject.directoryURL])

            return try GeneratedTests.commands(
                tool: executable,
                arguments: arguments,
                environment: environment,
                sources: testedTarget.inputFiles.filter { $0.type == .source }.map(\.url),
                config: config,
                testTargetDirectory: testTargetURL,
                outputDirectory: outputURL
            )
        }
    }
#endif

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { return self }
}
