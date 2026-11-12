import Foundation

/// `.prefire.yml`, read the way `prefire` reads it, for the little a plugin has to know before running it.
/// Plugins can't share code, so PrefirePlaybookPlugin has the same file.
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

    /// The value of `key` in `section`, without spaces and quotes; empty for a list.
    func value(of key: String, in section: String) -> String? {
        var currentSection: String?
        var value: String?
        for line in lines {
            if let section = Self.sections.first(where: { line.contains($0 + ":") }) {
                currentSection = section
                continue
            }
            let components = line.components(separatedBy: ":")
            guard currentSection == section, components.count > 1 else { continue }
            let name = components[0].replacing(" ", with: "").replacing("-", with: "")
            if name == key {
                value = components[components.count - 1]
                    .trimmingCharacters(in: .whitespaces)
                    .replacing("\"", with: "")
            }
        }
        return value
    }
}
