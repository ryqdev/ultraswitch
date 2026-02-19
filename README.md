# UltraSwitch

A macOS window switcher built with Swift and SwiftUI.

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+

## Build and Run

### Using Swift Package Manager

Build:

```bash
swift build
```

Run:

```bash
swift run UltraSwitch
```

Build for release:

```bash
swift build -c release
```

### Generate DMG

To create a `.dmg` installer for distribution:

```bash
bash scripts/build-dmg.sh
```

This builds the release binary, packages it into a `.app` bundle, and outputs `UltraSwitch.dmg` in the project root.

### Permissions

UltraSwitch requires **Accessibility** and **Screen Recording** permissions to function. The app will prompt you to grant these on first launch.
