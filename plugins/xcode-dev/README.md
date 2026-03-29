# xcode-dev

Xcode build and test skills for Claude Code. Works with or without [XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP).

## Skills

- **xcode-build** - Build an Xcode project by scheme. Automatically selects `build_macos` or `build_sim` when XcodeBuildMCP is available, falls back to `xcodebuild` direct execution.
- **xcode-test** - Run tests for files changed in git diff, or all tests with the `all` argument. Uses `@Test` annotation to detect test files.

## Setup

### With XcodeBuildMCP (recommended)

1. Install and configure [XcodeBuildMCP](https://github.com/getsentry/XcodeBuildMCP) as an MCP server
2. (Optional) Enable macOS workflow in `.xcodebuildmcp/config.yaml`:

```yaml
schemaVersion: 1
enabledWorkflows: ["simulator", "macos"]
```

No additional config files needed — session defaults handle project/scheme/simulator settings.

### Without XcodeBuildMCP

Create `.claude/skills/xcodebuild-config.yml` in your project root:

```yaml
workspace: MyApp.xcworkspace  # or project: MyApp.xcodeproj
scheme: MyApp
```

Optionally create `.claude/skills/xcodebuild-config.local.yml` for device settings (auto-detected if missing):

```yaml
device_id: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
device_name: iPhone 16
platform: iOS Simulator
os_version: "26.0"
```

Add `xcodebuild-config.local.yml` to `.gitignore` as it contains machine-specific settings.

## Usage

```
/xcode-build                        # Build all schemes
/xcode-build MyScheme               # Build a specific scheme
/xcode-test                         # Run tests for changed files
/xcode-test all                     # Run all tests
```
