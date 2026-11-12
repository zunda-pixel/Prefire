import Foundation
import PackagePlugin

/// `.prefire.yml`, read the way `prefire` reads it, for the little a plugin has to know before running it.
/// Plugins can't share code, so both plugins have this file; `make test-plugins` checks that they're the same.
struct PrefireConfigFile {
    static let fileName = ".prefire.yml"
    private static let sections = ["test_configuration", "playbook_configuration", "render_configuration"]

    let url: URL
    private let lines: [String]

    /// The `.prefire.yml` `prefire` uses: the first one in `directories`.
    static func first(in directories: [URL]) -> PrefireConfigFile? {
        for directory in directories {
            let url = directory.appending(path: fileName)
            if let data = try? Data(contentsOf: url) {
                let contents = String(decoding: data, as: UTF8.self)
                return PrefireConfigFile(url: url, lines: contents.components(separatedBy: .newlines))
            }
        }
        return nil
    }

    /// The value of `key` in `section`, without spaces and quotes, and with `${NAME}` replaced from
    /// `environment`, the variables the plugin sets for `prefire`. Empty for a list.
    func value(of key: String, in section: String, environment: [String: String]) -> String? {
        keyLines(of: key, in: section).last.map { index in
            let components = lines[index].components(separatedBy: ":")
            return Self.resolved(components[components.count - 1], environment: environment)
        }
    }

    /// The items of the list `key` in `section`, resolved like `value(of:in:environment:)`.
    func values(of key: String, in section: String, environment: [String: String]) -> [String]? {
        guard let index = keyLines(of: key, in: section).last,
              lines[index].components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces).isEmpty == true
        else { return nil }

        var values: [String] = []
        for line in lines[(index + 1)...] {
            guard !line.contains(":") else { break }
            let value = Self.resolved(line.replacing("- ", with: ""), environment: environment)
            if !value.isEmpty { values.append(value) }
        }
        return values
    }

    /// The Swift files of `sources` in `section`, which `prefire` reads instead of the target's; `nil` without it.
    func sourceFiles(in section: String, environment: [String: String]) -> [URL]? {
        values(of: "sources", in: section, environment: environment).map { paths in
            paths.flatMap { path in
                let files = Self.swiftFiles(at: URL(filePath: path))
                if files.isEmpty {
                    Diagnostics.warning("Prefire finds no Swift files at `\(path)` of `sources` in \(url.path). Give an existing file or directory, as an absolute path such as `${PACKAGE_DIR}/Sources/MyApp`.")
                }
                return files
            }
        }
    }

    /// The template of `section`, resolved like `prefire` from the directory in `baseKey`, or else from `defaultBase`.
    func template(in section: String, baseKey: String, defaultBase: URL, environment: [String: String]) -> URL? {
        guard let template = value(of: "template_file_path", in: section, environment: environment) else { return nil }
        let base = value(of: baseKey, in: section, environment: environment).map { URL(filePath: $0) } ?? defaultBase
        let url = base.appending(path: template)
        guard FileManager.default.fileExists(atPath: url.path) else {
            Diagnostics.warning("Prefire finds no template at \(url.path), from `template_file_path` and `\(baseKey)` in \(self.url.path), so editing the template doesn't run Prefire again.")
            return nil
        }
        return url
    }

    /// The Swift files at `url`, a file or a directory searched recursively, as `prefire` finds them.
    static func swiftFiles(at url: URL) -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return [] }
        guard isDirectory.boolValue else { return url.pathExtension == "swift" ? [url] : [] }

        var files: [URL] = []
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)
        while let file = enumerator?.nextObject() as? URL {
            if file.pathExtension == "swift" { files.append(file) }
        }
        return files.sorted { $0.path < $1.path }
    }

    /// The indices of the lines that set `key` in `section`.
    private func keyLines(of key: String, in section: String) -> [Int] {
        var currentSection: String?
        var indices: [Int] = []
        for (index, line) in lines.enumerated() {
            if let section = Self.sections.first(where: { line.contains($0 + ":") }) {
                currentSection = section
                continue
            }
            let components = line.components(separatedBy: ":")
            guard currentSection == section, components.count > 1 else { continue }
            if components[0].replacing(" ", with: "").replacing("-", with: "") == key {
                indices.append(index)
            }
        }
        return indices
    }

    private static func resolved(_ value: String, environment: [String: String]) -> String {
        var value = value.trimmingCharacters(in: .whitespaces).replacing("\"", with: "")
        if value.contains("${"),
           let name = value.components(separatedBy: "${").last?.components(separatedBy: "}").first,
           let replacement = environment[name] {
            value = value.replacing("${\(name)}", with: replacement)
        }
        // `prefire` warns about a variable left, with the same variables.
        return value
    }
}
