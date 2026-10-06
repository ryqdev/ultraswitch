# Repository Guidelines

## Project Structure & Module Organization

UltraSwitch is a macOS menu bar window switcher built with SwiftUI, AppKit, and ScreenCaptureKit. `Package.swift` defines one executable target and requires macOS 14+ with a Swift 5.9-compatible toolchain.

- `Sources/UltraSwitch/ultraswitchApp.swift`: application lifecycle, menu bar, and switcher coordination.
- `Sources/UltraSwitch/Managers/`: hotkey handling, permissions, window discovery, thumbnail capture, and activation.
- `Sources/UltraSwitch/Models/`: window data and identity (`WindowInfo`).
- `Sources/UltraSwitch/Views/`: switcher, thumbnail, and permission interfaces.
- `scripts/`: DMG packaging and icon generation.
- `AppIcon.icns`, `AppIcon.iconset/`, and `assets/icon.png`: application icons and README artwork.

## Build, Test, and Development Commands

Run commands from the repository root on macOS:

- `swift build`: compile the debug executable.
- `swift run UltraSwitch`: build and launch locally.
- `swift build -c release`: compile an optimized release executable.
- `bash scripts/build-dmg.sh`: build, bundle, ad-hoc sign, verify the signature, and create `UltraSwitch.dmg`.

Build output lives in `.build/`. Keep generated binaries, app bundles, and DMGs out of commits. Packaged builds are ad-hoc signed, not notarized.

## Coding Style & Naming Conventions

Follow existing Swift style: four-space indentation, opening braces on the declaration line, `UpperCamelCase` types, and `lowerCamelCase` methods and properties. Name new files after their primary type, such as `WindowInfo.swift`.

Keep platform operations in managers and presentation in views. Prefer `private` implementation details and `let` for immutable values. Preserve `@MainActor` isolation for UI-facing state and asynchronous thumbnail capture. No formatter or linter is configured; match nearby code and avoid unrelated reformatting.

## Testing Guidelines

There is currently no test target, testing framework configuration, or coverage threshold. `swift test` requires adding a test target to `Package.swift`; if introducing tests, use `Tests/UltraSwitchTests/` and descriptive `*Tests.swift` filenames.

For behavior changes, run `swift build` and manually check forward/reverse cycling, Command-release selection, Escape cancellation, thumbnail clicks, and multiple windows from the same app. Check Accessibility and Screen Recording permission flows when affected. Record macOS version and validation results in the PR.

## Commit & Pull Request Guidelines

Recent commits commonly use `feat:`, `fix:`, `refactor:`, `build:`, `docs:`, and `chore:` prefixes followed by a short, imperative summary. Follow that pattern and keep commits focused.

PRs should explain the problem, resulting behavior, and validation performed. Link relevant issues and include screenshots or recordings for visible interface changes. Call out permission, window-selection, or packaging changes explicitly.
