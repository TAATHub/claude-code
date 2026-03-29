---
name: xcode-build
description: Build Xcode project. Use after code changes to verify the build.
argument-hint: "Scheme name"
---

# Build

Build an Xcode project.

## Arguments

- Scheme name → Build the specified scheme only
- No arguments → Build all schemes (retrieved via `list_schemes`)

## Workflow

### Choosing the build method

- **macOS scheme**: Use XcodeBuildMCP `build_macos`
- **Otherwise**: Use XcodeBuildMCP `build_sim`

Determine whether a scheme targets macOS from context. If unknown, run `xcodebuild -showdestinations` to check.
