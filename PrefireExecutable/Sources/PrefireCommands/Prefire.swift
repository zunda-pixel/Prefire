@preconcurrency import ArgumentParser
import Foundation

/// The `prefire` command. A library, so the `prefire` CLI and the tool the plugins run share it.
public struct Prefire: AsyncParsableCommand {
    public static let configuration: CommandConfiguration = .init(
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

    public init() {}
}
