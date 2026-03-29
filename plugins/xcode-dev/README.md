# xcode-dev

Xcode build and test skills powered by [XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP).

## Skills

- **xcode-build** - Build an Xcode project by scheme. Automatically selects `build_macos` or `build_sim` based on the target platform.
- **xcode-test** - Run tests for files changed in git diff, or all tests with the `all` argument. Uses `@Test` annotation to detect test files.

## Prerequisites

### XcodeBuildMCP

This plugin requires [XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP) to be configured as an MCP server.

### macOS workflow (optional)

To build macOS targets via `build_macos`, enable the macOS workflow in `.xcodebuildmcp/config.yaml`:

```yaml
schemaVersion: 1
enabledWorkflows: ["simulator", "macos"]
```

Without this, only simulator-based targets (iOS, visionOS, etc.) can be built.

## Usage

```
/xcode-build                        # Build all schemes
/xcode-build MyScheme               # Build a specific scheme
/xcode-test                         # Run tests for changed files
/xcode-test all                     # Run all tests
```
