# UltraSwitch

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

### Permissions

UltraSwitch requires **Accessibility** and **Screen Recording** permissions to function. The app will prompt you to grant these on first launch.


### Fail to open?

```shell
xattr -cr /Applications/UltraSwitch.app
```
