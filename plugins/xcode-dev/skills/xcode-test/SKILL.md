---
name: xcode-test
description: Run tests only for files changed in git diff. Pass `all` to run all tests.
argument-hint: "Run type: `all` for all tests or no arguments for diff-based tests"
---

# Test

Run tests only for files changed in git diff.

## Arguments

| Argument | Description |
|----------|-------------|
| `all` | Run all tests |
| None | Run diff-based tests only |

## Workflow

### 1. Determine test targets

If `all` is passed, skip this step and run all tests.

Otherwise:

```bash
git diff HEAD --name-only
```

- Filter changed files to those containing the `@Test` annotation
- If no test files are found, report "No test targets" and skip
- Strip `.swift` from filenames to get test class names

### 2. Run tests

If XcodeBuildMCP tools are available, use **Path A**. Otherwise, use **Path B**.

---

#### Path A: XcodeBuildMCP

**All tests (`all`):**

Call `test_sim` with no arguments.

**Diff-based tests:**

Call `test_sim` with:

- extraArgs: `["-only-testing:TestTarget/TestClassName1", "-only-testing:TestTarget/TestClassName2"]`
- Determine the test target name from context. If unknown, inspect the project's test targets.

---

#### Path B: xcodebuild direct

Load config from `xcodebuild-config.yml` and `xcodebuild-config.local.yml` (see xcode-build skill for details).

**All tests (`all`):**

```bash
xcodebuild test \
  -workspace ${workspace} \
  -scheme ${scheme} \
  -destination 'platform=${platform},id=${device_id}'
```

**Diff-based tests:**

```bash
xcodebuild test \
  -workspace ${workspace} \
  -scheme ${scheme} \
  -destination 'platform=${platform},id=${device_id}' \
  -only-testing:TestTarget/TestClassName1 \
  -only-testing:TestTarget/TestClassName2
```

- Determine the test target name from context. If unknown, inspect the project's test targets.
