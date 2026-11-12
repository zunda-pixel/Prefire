#if os(macOS)
import ArgumentParser
import Foundation

/// A run by a build tool plugin. The plugin reads `.prefire.yml` and works out the files Prefire writes before it
/// runs Prefire, so Prefire takes what the plugin decided instead of reading it again: the sources (from the
/// arguments, not `sources`), the variables to replace and whether the snapshots are grouped. It doesn't read
/// `test_file_path` or a `.prefire.yml` in the working directory either, and writes only the files that follow.
struct PluginRun {
    /// The variables the plugin replaced in `.prefire.yml`. Xcode passes its environment on to the build command,
    /// so Prefire doesn't take them from there.
    let variables: [String: String]
    /// Whether the plugin generates one file with every preview; `nil` for the Playbook, which always does.
    let groupedSnapshots: Bool?

    /// - Parameter variables: `NAME=VALUE` pairs.
    init?(isPluginRun: Bool, variables: [String], groupedSnapshots: Bool? = nil) throws {
        guard isPluginRun else { return nil }
        self.variables = try Dictionary(variables.map { pair in
            guard let separator = pair.firstIndex(of: "=") else {
                throw ValidationError("A plugin variable is NAME=VALUE, not '\(pair)'.")
            }
            return (String(pair[..<separator]), String(pair[pair.index(after: separator)...]))
        }, uniquingKeysWith: { _, last in last })
        self.groupedSnapshots = groupedSnapshots
    }

    /// The variables to replace in `.prefire.yml` for `run`.
    static func environment(for run: PluginRun?) -> [String: String] {
        run?.variables ?? ProcessInfo.processInfo.environment
    }
}
#endif
