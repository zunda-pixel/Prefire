#if os(macOS)
@preconcurrency import ArgumentParser
import Foundation

@main
struct Prefire: AsyncParsableCommand {
    static let configuration: CommandConfiguration = .init(
        commandName: "prefire",
        abstract: "A tool to easy generation: Playbook and Snapshot/Accessibility Tests.",
        version: Version.value,
        subcommands: [
            Playbook.self,
            Tests.self,
            Render.self,
            Board.self,
            MCP.self,
            Version.self
        ]
    )
}
#else
/// The CLI runs on the Mac, where the plugins build it. The package also builds for iOS: nothing to do there.
@main
enum Prefire {
    static func main() {}
}
#endif
