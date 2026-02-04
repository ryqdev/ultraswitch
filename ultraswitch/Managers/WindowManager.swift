//
//  WindowManager.swift
//  ultraswitch
//

import AppKit
import ApplicationServices
import Combine
import ScreenCaptureKit

@MainActor
final class WindowManager: ObservableObject {
    static let shared = WindowManager()

    @Published private(set) var windows: [WindowInfo] = []
    private var isRefreshing = false

    private let excludedOwners: Set<String> = [
        "Dock",
        "Window Server",
        "Notification Center",
        "Control Center",
        "SystemUIServer",
        "Spotlight",
        "loginwindow",
        "ultraswitch"
    ]

    private let minimumWindowSize: CGFloat = 50

    private init() {}

    // Use CGWindowList (fast) instead of ScreenCaptureKit (slow)
    func refreshWindows() {
        guard !isRefreshing else {
            print("WindowManager: Already refreshing, skipping")
            return
        }
        isRefreshing = true

        print("WindowManager: Starting window refresh...")
        let startTime = CFAbsoluteTimeGetCurrent()

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            print("WindowManager: Failed to get window list")
            isRefreshing = false
            return
        }

        var windowInfos: [WindowInfo] = []

        for windowDict in windowList {
            guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = windowDict[kCGWindowOwnerPID as String] as? pid_t,
                  let ownerName = windowDict[kCGWindowOwnerName as String] as? String,
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = windowDict[kCGWindowLayer as String] as? Int else {
                continue
            }

            // Only normal windows (layer 0)
            if layer != 0 { continue }

            // Skip excluded apps
            if excludedOwners.contains(ownerName) { continue }

            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            // Skip tiny windows
            if bounds.width < minimumWindowSize || bounds.height < minimumWindowSize { continue }

            let title = windowDict[kCGWindowName as String] as? String ?? ""

            let windowInfo = WindowInfo(
                id: windowID,
                ownerPID: ownerPID,
                ownerName: ownerName,
                windowTitle: title,
                bounds: bounds,
                thumbnail: nil,
                axWindow: nil
            )

            windowInfos.append(windowInfo)
        }

        self.windows = windowInfos
        isRefreshing = false

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("WindowManager: Found \(windowInfos.count) windows in \(String(format: "%.3f", elapsed))s")
    }

    func captureThumbnails() async {
        guard !windows.isEmpty else { return }

        print("WindowManager: Starting thumbnail capture for \(windows.count) windows...")
        let startTime = CFAbsoluteTimeGetCurrent()

        // Get shareable content
        guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) else {
            print("WindowManager: Failed to get shareable content")
            return
        }

        print("WindowManager: SCShareableContent has \(content.windows.count) windows")

        // Build a lookup map
        let scWindowMap = Dictionary(uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) })

        // Capture thumbnails in parallel
        var capturedCount = 0
        await withTaskGroup(of: (Int, NSImage?).self) { group in
            for (index, windowInfo) in windows.enumerated() {
                if let scWindow = scWindowMap[windowInfo.id] {
                    group.addTask {
                        let thumbnail = await self.captureThumbnail(for: scWindow)
                        return (index, thumbnail)
                    }
                }
            }

            var updatedWindows = windows
            for await (index, thumbnail) in group {
                if let thumbnail = thumbnail, index < updatedWindows.count {
                    updatedWindows[index].thumbnail = thumbnail
                    capturedCount += 1
                }
            }
            self.windows = updatedWindows
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("WindowManager: Captured \(capturedCount) thumbnails in \(String(format: "%.3f", elapsed))s")
    }

    private func captureThumbnail(for scWindow: SCWindow) async -> NSImage? {
        do {
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            config.width = 300
            config.height = 200
            config.scalesToFit = true
            config.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        } catch {
            return nil
        }
    }

    private func findAXWindow(for windowID: CGWindowID, pid: pid_t, bounds: CGRect) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return nil
        }

        for window in windows {
            var positionRef: CFTypeRef?
            var sizeRef: CFTypeRef?

            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

            guard let positionValue = positionRef,
                  let sizeValue = sizeRef else { continue }

            var position = CGPoint.zero
            var size = CGSize.zero

            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

            let tolerance: CGFloat = 5
            if abs(position.x - bounds.origin.x) < tolerance &&
               abs(position.y - bounds.origin.y) < tolerance &&
               abs(size.width - bounds.width) < tolerance &&
               abs(size.height - bounds.height) < tolerance {
                return window
            }
        }

        return windows.first
    }

    func activateWindow(_ windowInfo: WindowInfo) {
        let axWindow = findAXWindow(for: windowInfo.id, pid: windowInfo.ownerPID, bounds: windowInfo.bounds)

        if let axWindow = axWindow {
            AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        }

        if let app = NSRunningApplication(processIdentifier: windowInfo.ownerPID) {
            app.activate()
        }
    }
}
