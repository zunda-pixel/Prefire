import Foundation
import PathKit

/// A run by a build tool plugin, which passes the files it declared with `--declared-output`. The plugin reads
/// `.prefire.yml` before it runs Prefire, so Prefire reads it the same way then: only from the paths the plugin
/// passes, without `test_file_path`, and replacing only the variables the plugin sets.
struct PluginRun {
    /// The variables the plugins set for Prefire. Xcode passes its own environment on as well.
    private static let variables: Set<String> = ["PACKAGE_DIR", "TARGET_DIR", "PROJECT_DIR"]

    let declaredOutputs: [Path]

    init?(declaredOutputs: [String]) {
        guard !declaredOutputs.isEmpty else { return nil }
        self.declaredOutputs = declaredOutputs.map { Path($0) }
    }

    /// The variables to replace in `.prefire.yml` for `run`.
    static func environment(for run: PluginRun?) -> [String: String] {
        let environment = ProcessInfo.processInfo.environment
        guard run != nil else { return environment }
        return environment.filter { variables.contains($0.key) }
    }
}
