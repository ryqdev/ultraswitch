//
//  ultraswitchApp.swift
//  ultraswitch
//

import AppKit
import Combine
import SwiftUI

@main
struct UltraswitchApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var switcherWindow: NSWindow?
    private var switcherHostingView: NSHostingView<SwitcherView>?
    private var permissionWindow: NSWindow?

    private let hotkeyManager = HotkeyManager.shared
    private let windowManager = WindowManager.shared
    private let permissionManager = PermissionManager.shared

    private var selectedIndex = 0
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotkeyCallbacks()

        // Check Accessibility permission synchronously (fast)
        let hasAccessibility = permissionManager.checkAccessibilityPermission()

        if hasAccessibility {
            // Start hotkey manager immediately - this only needs Accessibility permission
            startHotkeyManager()

            // Check Screen Recording permission in background
            Task { @MainActor in
                await permissionManager.checkPermissionsAsync()
                if !permissionManager.hasScreenRecordingPermission {
                    // Show permission window but hotkey is already working
                    showPermissionWindow()
                }
            }
        } else {
            // No Accessibility permission - show permission window and wait
            Task { @MainActor in
                await permissionManager.checkPermissionsAsync()
                showPermissionWindow()
                permissionManager.startPermissionMonitoring()
                observePermissionChanges()
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "square.on.square", accessibilityDescription: "UltraSwitch")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Check Permissions", action: #selector(showPermissionWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit UltraSwitch", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func setupHotkeyCallbacks() {
        hotkeyManager.onSwitcherActivate = { [weak self] in
            Task { @MainActor in
                self?.showSwitcher()
            }
        }

        hotkeyManager.onTabPressed = { [weak self] isShift in
            Task { @MainActor in
                self?.cycleSelection(reverse: isShift)
            }
        }

        hotkeyManager.onCommandReleased = { [weak self] in
            Task { @MainActor in
                self?.activateAndDismiss()
            }
        }

        hotkeyManager.onEscapePressed = { [weak self] in
            Task { @MainActor in
                self?.dismissSwitcher()
            }
        }
    }

    private func startHotkeyManager() {
        let success = hotkeyManager.start()
        if !success {
            print("Failed to start hotkey manager")
            Task { @MainActor in
                showPermissionWindow()
            }
        }
    }

    private func observePermissionChanges() {
        permissionManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    // Only need Accessibility permission for hotkey to work
                    if self.permissionManager.hasAccessibilityPermission {
                        self.permissionManager.stopPermissionMonitoring()
                        self.startHotkeyManager()
                        self.cancellables.removeAll()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private var isSwitcherActive = false
    private var isSwitcherUIVisible = false
    private var showUITask: Task<Void, Never>?
    private let showUIDelay: UInt64 = 80_000_000 // 80ms in nanoseconds

    @MainActor
    private func showSwitcher() {
        // If already active, cancel previous session and restart
        if isSwitcherActive {
            showUITask?.cancel()
            showUITask = nil
            if isSwitcherUIVisible {
                switcherWindow?.orderOut(nil)
            }
        }
        isSwitcherActive = true
        isSwitcherUIVisible = false

        print("AppDelegate: showSwitcher called")
        // Start at index 1 (second window) since index 0 is the current window
        selectedIndex = 1

        // Get window list synchronously (fast with CGWindowList)
        print("AppDelegate: Starting window refresh...")
        windowManager.refreshWindows()
        print("AppDelegate: Window refresh complete, count=\(windowManager.windows.count)")

        if windowManager.windows.isEmpty {
            print("AppDelegate: No windows found, dismissing")
            isSwitcherActive = false
            return
        }

        // Adjust selectedIndex if there's only one window
        if windowManager.windows.count == 1 {
            selectedIndex = 0
        }

        // Start thumbnail capture and delay in parallel, wait for BOTH before showing UI
        showUITask = Task { @MainActor in
            // Run both in parallel
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await self.windowManager.captureThumbnails()
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: self.showUIDelay)
                }
                // Wait for both to complete
                await group.waitForAll()
            }

            // Check if still active (user hasn't released Cmd)
            guard isSwitcherActive else { return }

            showSwitcherUI()
        }
    }

    @MainActor
    private func showSwitcherUI() {
        guard isSwitcherActive, !isSwitcherUIVisible else { return }
        isSwitcherUIVisible = true

        createSwitcherWindow()
        switcherWindow?.orderFrontRegardless()
    }

    @MainActor
    private func createSwitcherWindow() {
        guard let screen = NSScreen.main else { return }

        if let existingWindow = switcherWindow {
            // Reuse existing window, just update the view
            existingWindow.setFrame(screen.frame, display: true)
            updateSwitcherView()
            return
        }

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Set the window frame explicitly to cover the entire screen
        window.setFrame(screen.frame, display: true)
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false

        let switcherView = SwitcherView(
            selectedIndex: selectedIndex,
            onWindowSelected: { [weak self] (windowInfo: WindowInfo) in
                self?.activateWindow(windowInfo)
            }
        )

        let hostingView = NSHostingView(rootView: switcherView)
        window.contentView = hostingView

        switcherWindow = window
        switcherHostingView = hostingView
    }

    @MainActor
    private func updateSwitcherView() {
        let switcherView = SwitcherView(
            selectedIndex: selectedIndex,
            onWindowSelected: { [weak self] (windowInfo: WindowInfo) in
                self?.activateWindow(windowInfo)
            }
        )
        switcherHostingView?.rootView = switcherView
    }

    @MainActor
    private func cycleSelection(reverse: Bool) {
        guard !windowManager.windows.isEmpty else { return }

        if reverse {
            selectedIndex = (selectedIndex - 1 + windowManager.windows.count) % windowManager.windows.count
        } else {
            selectedIndex = (selectedIndex + 1) % windowManager.windows.count
        }

        // If user presses Tab again, show UI immediately
        if !isSwitcherUIVisible {
            showUITask?.cancel()
            showSwitcherUI()
        } else {
            updateSwitcherView()
        }
    }

    @MainActor
    private func activateAndDismiss() {
        guard isSwitcherActive else { return }
        guard !windowManager.windows.isEmpty,
              selectedIndex >= 0,
              selectedIndex < windowManager.windows.count else {
            dismissSwitcher()
            return
        }

        let windowInfo = windowManager.windows[selectedIndex]
        activateWindow(windowInfo)
    }

    @MainActor
    private func activateWindow(_ windowInfo: WindowInfo) {
        windowManager.activateWindow(windowInfo)
        dismissSwitcher()
    }

    @MainActor
    private func dismissSwitcher() {
        showUITask?.cancel()
        showUITask = nil
        if isSwitcherUIVisible {
            switcherWindow?.orderOut(nil)
        }
        isSwitcherActive = false
        isSwitcherUIVisible = false
    }

    @objc private func showPreferences() {
        Task { @MainActor in
            showPermissionWindow()
        }
    }

    @MainActor
    @objc private func showPermissionWindow() {
        // Always create a fresh window to avoid stale references
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "UltraSwitch"
        window.contentView = NSHostingView(rootView: PermissionRequestView())
        window.center()
        window.isReleasedWhenClosed = false
        permissionWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        hotkeyManager.stop()
        NSApp.terminate(nil)
    }
}
