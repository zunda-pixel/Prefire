import PrefireCommands

// Empty: `Prefire` has all @main needs, the async static main() of AsyncParsableCommand.
// A top-level `await Prefire.main()` in main.swift would pick the synchronous main() of ParsableCommand.
@main
extension Prefire {}
