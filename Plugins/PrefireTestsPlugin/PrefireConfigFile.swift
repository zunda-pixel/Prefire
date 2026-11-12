import Foundation

/// `.prefire.yml`, read the way `prefire` reads it, for the little a plugin has to know before running it.
/// Plugins can't share code, so PrefirePlaybookPlugin links to this file.
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
    /// `environment`, the environment `prefire` runs with. Empty for a list.
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
        return value
    }
}
