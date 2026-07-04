# Contributing to TestableUIKit

Thank you for your interest in contributing to TestableUIKit!
This guide walks you through the process of reporting bugs, proposing features, and submitting pull requests.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Requesting Features](#requesting-features)
  - [Submitting a Pull Request](#submitting-a-pull-request)
- [Development Setup](#development-setup)
- [Coding Guidelines](#coding-guidelines)
- [Testing](#testing)
- [Release Process](#release-process)

---

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you agree to uphold this standard.
Please report unacceptable behavior to [ironasam43@icloud.com](mailto:ironasam43@icloud.com).

---

## How to Contribute

### Reporting Bugs

1. Search [existing issues](https://github.com/ironasam43/TestableUIKit/issues) to see if the bug has already been reported.
2. If not, open a new issue using the **Bug Report** template.
3. Include steps to reproduce, expected behavior, and actual behavior.
4. Attach relevant logs or screenshots when possible.

### Requesting Features

1. Search [existing issues](https://github.com/ironasam43/TestableUIKit/issues) for similar requests.
2. If your idea is new, open an issue using the **Feature Request** template.
3. Describe the use case and the expected behavior clearly.

### Submitting a Pull Request

1. **Fork** the repository and create a new branch from `main`:
   ```sh
   git checkout -b feature/your-feature-name
   ```
2. Make your changes following the [Coding Guidelines](#coding-guidelines) below.
3. Add or update tests for any changed logic.
4. Update documentation if your change affects behavior or APIs.
5. Add an entry to `CHANGELOG.md` under `[Unreleased]`.
6. Run the full test suite and ensure it passes (see [Testing](#testing)).
7. Open a pull request against `main` using the **Pull Request Template**.
8. Address any review feedback promptly.

---

## Development Setup

### Prerequisites

- **Xcode 15+** (for iOS/macOS targets)
- **Swift 5.9+** (`swift --version`)
- **Python 3** (for the IPC test runner)

### Build

```sh
# Build all targets
swift build

# Build the MCP Swift server
cd mcp-swift && swift build
```

### Run Tests

```sh
# Run Swift unit tests
swift test

# Run IPC integration tests (requires DemoApp running)
python3 run_test.py
```

---

## Coding Guidelines

These rules apply to all Swift source files in this repository.

| Rule | Convention |
|------|-----------|
| **Indentation** | 2 spaces (no tabs) |
| **Naming** | camelCase for variables/functions; PascalCase for types |
| **Comments** | English only |
| **Commit prefix** | `feat:` / `fix:` / `docs:` / `refactor:` / `test:` |

### Example Commit Messages

```
feat: add ui_screenshot fallback via simctl
fix: handle partial NWConnection reads in TestableServer
docs: update ipc-protocol with decrement/reset commands
refactor: extract ScenarioEvaluator from main.swift
test: add ScenarioActionTests for known command constants
```

---

## Testing

### Test Layers

| Layer | Tool | When required |
|-------|------|---------------|
| **L1 Logic** | XCTest (`swift test`) | Required for any change to pure functions, state management, data transforms, or ViewModels |
| **L3 UI State** | TestableUIKit IPC (`run_test.py`) | For runtime UI behavior on Simulator/device |
| **L5 Manual** | Human on device | Only for items that cannot be mechanically verified |

Please ensure `swift test` passes before opening a PR.

---

## Release Process

Releases follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking API changes
- **MINOR**: New backward-compatible functionality
- **PATCH**: Backward-compatible bug fixes

Steps to cut a release:
1. Update `CHANGELOG.md`: rename `[Unreleased]` to `[vX.Y.Z] - YYYY-MM-DD`.
2. Commit: `docs: release vX.Y.Z`
3. Tag: `git tag vX.Y.Z && git push origin vX.Y.Z`
4. Create a GitHub Release from the tag.

---

*Questions? Open an issue or email [ironasam43@icloud.com](mailto:ironasam43@icloud.com).*
