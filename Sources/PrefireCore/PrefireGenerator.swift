import Foundation
import PathKit

public enum PrefireGenerator {
    nonisolated(unsafe) static var startTime = Date()

    public static func generate(
        version: String,
        sources: [Path],
        output: Path,
        arguments: [String: NSObject],
        inlineTemplate: String,
        defaultEnabled: Bool,
        cacheDir: Path? = nil,
        useGroupedSnapshots: Bool,
        declaredOutputs: [Path]? = nil
    ) async throws {
        startTime = Date()
        let writer = OutputWriter(declaredOutputs: declaredOutputs)

        var discovered: Set<Path> = []
        try sources.forEach { path in
            if path.isDirectory {
                discovered.formUnion(try path.recursiveChildren().filter { $0.extension == "swift" })
            } else if path.extension == "swift" {
                discovered.insert(path)
            }
        }

        guard !discovered.isEmpty else {
            if declaredOutputs != nil {
                // "warning:" makes Xcode and SwiftPM show it as a build warning.
                Logger.warning("warning: Prefire found no Swift sources in \(sources.map(\.string).joined(separator: ", ")), so the generated files have no previews.")
            } else {
                Logger.info("No Swift sources found to process.")
            }
            try writer.writeUnwrittenDeclaredOutputs()
            return
        }

        // Sorted so the order of the generated declarations does not depend on set iteration order.
        let swiftFiles = discovered.sorted { $0.string < $1.string }

        // If use grouped is false, we geneate one file per tests
        // and use the template as output replacing the "{PREVIEW_FILE_NAME}" with the name of the file

        let manager = PrefireCacheManager(version: version, cacheBasePath: cacheDir)
        let (types, previews) = try manager.load(sources: swiftFiles, defaultEnabled: defaultEnabled) { path in
            let content = try path.read(.utf8)
            let previews = content.contains("#Preview")
                ? PreviewLoader.previewModels(from: content, filename: path.lastComponentWithoutExtension, defaultEnabled: defaultEnabled)
                : nil
            return ParsedSource(types: TypeScanner.scan(contents: content), previews: previews ?? [:])
        }

        let previewModels = previews
            .sorted { $0.key > $1.key }
            .compactMap { entry -> [String: Any?]? in
                var dict = entry.value.makeStencilDict()
                // Add the source filename for ungrouped generation
                dict["sourceFileName"] = extractFileNameFromKey(entry.key)
                return dict
            }

        let context = StencilContext(graph: TypeGraph(types: types))

        if useGroupedSnapshots {
            // Generate one file with all previews
            var arguments = arguments
            arguments["previewsMacrosDict"] = previewModels as NSArray
            
            // For grouped snapshots, replace {PREVIEW_FILE_NAME} with "Preview" to maintain current class name
            let customizedTemplate = inlineTemplate.replacingOccurrences(of: "{PREVIEW_FILE_NAME}", with: "Preview")
            
            try renderAndWrite(context: context, inlineTemplate: customizedTemplate, output: output, arguments: arguments, writer: writer)
        } else {
            // Generate one file per source file containing previews
            try generateUngroupedFiles(
                previewModels: previewModels,
                context: context,
                inlineTemplate: inlineTemplate,
                output: output,
                arguments: arguments,
                writer: writer
            )
        }

        try writer.writeUnwrittenDeclaredOutputs()

        Logger.info("✅ Generation completed in \(startTime.distance(to: Date()).formatted())")
    }

    private static func generateUngroupedFiles(
        previewModels: [[String: Any?]],
        context: StencilContext,
        inlineTemplate: String,
        output: Path,
        arguments: [String: NSObject],
        writer: OutputWriter
    ) throws {
        // Group preview models by their source file name
        var groupedByFile: [String: [[String: Any?]]] = [:]
        for previewModel in previewModels {
            guard let fileName = previewModel["sourceFileName"] as? String else { continue }
            groupedByFile[fileName, default: []].append(previewModel)
        }

        Logger.info("📝 Generating \(groupedByFile.count) separate test files...")

        for (fileName, models) in groupedByFile {
            // Replace the placeholder in the output path
            let outputPath = replacePreviewFileName(in: output, with: fileName)
            
            var fileArguments = arguments
            fileArguments["previewsMacrosDict"] = models as NSArray

            // Resolve the placeholder in any string-valued arguments so values like the
            // `file` path (used by SnapshotTesting to derive the per-class `__Snapshots__`
            // folder) point at the per-source generated file rather than a literal placeholder.
            for (key, value) in fileArguments {
                guard let stringValue = value as? NSString,
                      stringValue.contains("{PREVIEW_FILE_NAME}") else { continue }
                let resolved = (stringValue as String).replacingOccurrences(of: "{PREVIEW_FILE_NAME}", with: fileName)
                fileArguments[key] = resolved as NSString
            }

            // Replace the placeholder in the template as well
            let customizedTemplate = inlineTemplate.replacingOccurrences(of: "{PREVIEW_FILE_NAME}", with: fileName)
            
            Logger.info("🖋 Rendering template for \(fileName)...")
            try renderAndWrite(
                context: context,
                inlineTemplate: customizedTemplate,
                output: outputPath,
                arguments: fileArguments,
                writer: writer
            )
        }
    }
    
    private static func extractFileNameFromKey(_ key: String) -> String {
        // Key format is "FileName_index", extract just the file name part
        let components = key.components(separatedBy: "_")
        guard !components.isEmpty else { return key }
        
        // If the last component is a number, it's likely an index
        if components.count > 1 && Int(components.last!) != nil {
            return components.dropLast().joined(separator: "_")
        }
        
        return key
    }
    
    private static func replacePreviewFileName(in path: Path, with fileName: String) -> Path {
        let pathString = path.string
        let updatedPath = pathString.replacingOccurrences(of: "{PREVIEW_FILE_NAME}", with: fileName)
        return Path(updatedPath)
    }

    private static func renderAndWrite(
        context: StencilContext,
        inlineTemplate: String,
        output: Path,
        arguments: [String: NSObject],
        writer: OutputWriter
    ) throws {
        Logger.info("🖋 Rendering template...")
        let rendered = try TemplateRenderer.render(
            template: inlineTemplate,
            context: context.dictionary(arguments: arguments)
        )

        try writer.write(rendered, to: output)
    }
}

/// Writes the generated files. A build tool plugin declares its output files before Prefire runs: then
/// Prefire writes only those, and a comment into the ones it has no previews for.
private final class OutputWriter {
    private let declaredOutputs: Set<Path>?
    private var written: Set<Path> = []

    init(declaredOutputs: [Path]?) {
        self.declaredOutputs = declaredOutputs.map { Set($0.map { $0.absolute().normalize() }) }
    }

    func write(_ rendered: String, to output: Path) throws {
        let output = output.absolute().normalize()
        if let declaredOutputs, !declaredOutputs.contains(output) {
            throw PrefireGeneratorError.undeclaredOutput(output.string)
        }
        written.insert(output)

        if output.exists, (try? output.read()) == Data(rendered.utf8) {
            Logger.info("✅ Output unchanged, keeping file: \(output)")
            return
        }

        Logger.info("💾 Writing to file: \(output)")
        try output.parent().mkpath()
        try output.write(rendered)
    }

    func writeUnwrittenDeclaredOutputs() throws {
        guard let declaredOutputs else { return }
        for output in declaredOutputs.subtracting(written).sorted(by: { $0.string < $1.string }) {
            try write("// Generated by Prefire: no enabled previews.\n", to: output)
        }
    }
}

public enum PrefireGeneratorError: Error, CustomStringConvertible, Equatable {
    case undeclaredOutput(String)

    public var description: String {
        switch self {
        case let .undeclaredOutput(path):
            return "❌ Prefire error: the build tool plugin didn't declare \(path), so it can't be built. Build again, and if this happens again, please report it."
        }
    }
}

private extension Path {
    var lastComponentWithoutExtension: String {
        self.lastComponent.components(separatedBy: ".").dropLast().joined(separator: ".")
    }
}
