# Contributing to Prefire

Contributions are welcome! To propose a change:

1. Fork the repository
2. Create a feature branch
3. Submit a Pull Request

## Development setup

Run `make` to list the development tasks. The ones you need most:

```bash
make build      # Build Prefire for the iOS Simulator
swift test      # Run the Prefire macOS tests
make test-ios   # Run the Prefire library tests on an iPhone simulator
make test       # Run the PrefireExecutable unit tests
make test-cli   # Run the PrefireCLI unit tests
make test-plugins  # Build PrefirePluginTests, a macOS package that uses both plugins
```

CI runs the same commands, see [.github/workflows/swift.yml](.github/workflows/swift.yml).

The [Example](Example) project shows Prefire in an Xcode app with a snapshot test target.

## Internal architecture

- `PrefireCore` — AST + preview parsing, caching, logic
- `PrefireGenerator` — handles stencil templating + snapshot generation
- `PrefireCacheManager` — unifies caching for `Types` and `Previews`
- `PrefireCommands` — the `prefire` commands, shared by the CLI and the plugins
- `PrefireTestsPlugin` / `PrefirePlaybookPlugin` — SPM/Xcode integrations, which build `PrefireTool` from these sources
- `prefire` — CLI entry point, calls shared generator code

The sources live in `PrefireExecutable`, a package of its own for `make test` and the release binary. The root `Package.swift` builds the same sources for the plugins, so keep the dependencies of both manifests in step.

Generated code comes from [Stencil templates](Documentation/Templates.md).
