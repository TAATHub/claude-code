---
name: xcode-build
description: Build Xcode project. Use after code changes to verify the build.
argument-hint: "Scheme name"
---

# Build

Build an Xcode project.

## Arguments

- Scheme name → Build the specified scheme only
- No arguments → Build all schemes (retrieved via `list_schemes` or project config)

## Workflow

### Choosing the backend

If XcodeBuildMCP tools are available, use **Path A**. Otherwise, use **Path B**.

---

### Path A: XcodeBuildMCP

- **macOS scheme**: Use `build_macos`
- **Otherwise**: Use `build_sim`

Determine whether a scheme targets macOS from context. If unknown, run `xcodebuild -showdestinations` to check.

---

### Path B: xcodebuild direct

#### 1. Load config

Read `${PROJECT_DIR}/.claude/skills/xcodebuild-config.yml`:

```yaml
workspace: MyApp.xcworkspace  # or project: MyApp.xcodeproj
scheme: MyApp
```

Read `${PROJECT_DIR}/.claude/skills/xcodebuild-config.local.yml`:

```yaml
device_id: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
device_name: iPhone 16
platform: iOS Simulator
os_version: "26.0"
```

If `xcodebuild-config.local.yml` is missing or `device_id` is empty, auto-detect:

```bash
xcrun simctl list devices available
```

- Select the latest OS iPhone device
- Write `device_id`, `device_name`, `platform`, `os_version` to `xcodebuild-config.local.yml`

#### 2. Build

```bash
xcodebuild \
  -workspace ${workspace} \
  -scheme ${scheme} \
  -destination 'platform=${platform},id=${device_id}' \
  build
```

For macOS schemes (no simulator): `-destination 'platform=macOS'`
