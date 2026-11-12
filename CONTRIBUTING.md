# Contributing to Prefire

Contributions are welcome! To propose a change:

1. Fork the repository
2. Create a feature branch
3. Submit a Pull Request

## Development setup

Run `make` to list the development tasks. The ones you need most:

```bash
make build      # Build Prefire for the iOS Simulator
swift test      # Run the macOS tests: the Prefire library, PrefireCore and the CLI
make test-ios   # Run the Prefire library tests on an iPhone simulator
make test-plugins  # Build PrefirePluginTests, a macOS package that uses both plugins
```

CI runs the same commands, see [.github/workflows/swift.yml](.github/workflows/swift.yml).

The [Example](Example) project shows Prefire in an Xcode app with a snapshot test target.

## Internal architecture

- `PrefireCore` — AST + preview parsing, caching, logic
- `PrefireGenerator` — handles stencil templating + snapshot generation
- `PrefireCacheManager` — unifies caching for `Types` and `Previews`
- `PrefireTool` — the `prefire` CLI, calls shared generator code. The plugins build and run it, and the release binary is built from it
- `PrefireTestsPlugin` / `PrefirePlaybookPlugin` — SPM/Xcode integrations

Generated code comes from [Stencil templates](Documentation/Templates.md).
