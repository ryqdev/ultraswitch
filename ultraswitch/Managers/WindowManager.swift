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

        // Group windows by ownerPID to detect duplicates from same app
        var windowsByPID: [pid_t: [(windowDict: [String: Any], bounds: CGRect, title: String)]] = [:]

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

            // Skip narrow untitled windows (sidebars, panels like Brave's vertical tabs)
            if title.isEmpty && bounds.width < 300 { continue }

            // Check window alpha (transparent overlays should be skipped)
            if let alpha = windowDict[kCGWindowAlpha as String] as? CGFloat, alpha < 0.9 {
                continue
            }

            // Group by PID for duplicate detection
            if windowsByPID[ownerPID] == nil {
                windowsByPID[ownerPID] = []
            }
            windowsByPID[ownerPID]?.append((windowDict: windowDict, bounds: bounds, title: title))
        }

        // Process windows and filter duplicates
        for (ownerPID, windows) in windowsByPID {
            // If multiple windows from same app, filter out potential popups/search boxes
            if windows.count > 1 {
                // Sort by area (largest first) - main window is usually largest
                let sorted = windows.sorted { w1, w2 in
                    let area1 = w1.bounds.width * w1.bounds.height
                    let area2 = w2.bounds.width * w2.bounds.height
                    return area1 > area2
                }

                // Keep windows that are significantly different in size or position
                var keptWindows: [(windowDict: [String: Any], bounds: CGRect, title: String)] = []
                for window in sorted {
                    var shouldKeep = true

                    // Check if this window is much smaller and overlapping with a kept window
                    // (likely a popup/search box)
                    for kept in keptWindows {
                        let keptArea = kept.bounds.width * kept.bounds.height
                        let currentArea = window.bounds.width * window.bounds.height

                        // If this window is <50% of the size and overlaps, skip it
                        if currentArea < keptArea * 0.5 && window.bounds.intersects(kept.bounds) {
                            shouldKeep = false
                            break
                        }
                    }

                    if shouldKeep {
                        keptWindows.append(window)
                    }
                }

                // Add kept windows to final list
                for window in keptWindows {
                    let windowDict = window.windowDict
                    guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                          let ownerName = windowDict[kCGWindowOwnerName as String] as? String else {
                        continue
                    }

                    let windowInfo = WindowInfo(
                        id: windowID,
                        ownerPID: ownerPID,
                        ownerName: ownerName,
                        windowTitle: window.title,
                        bounds: window.bounds,
                        thumbnail: nil,
                        axWindow: nil
                    )
                    windowInfos.append(windowInfo)
                }
            } else if let window = windows.first {
                // Single window from this app, add it directly
                let windowDict = window.windowDict
                guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                      let ownerName = windowDict[kCGWindowOwnerName as String] as? String else {
                    continue
                }

                let windowInfo = WindowInfo(
                    id: windowID,
                    ownerPID: ownerPID,
                    ownerName: ownerName,
                    windowTitle: window.title,
                    bounds: window.bounds,
                    thumbnail: nil,
                    axWindow: nil
                )
                windowInfos.append(windowInfo)
            }
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

        // Don't return a random window if no match found
        return nil
    }

    func activateWindow(_ windowInfo: WindowInfo) {
        let axWindow = findAXWindow(for: windowInfo.id, pid: windowInfo.ownerPID, bounds: windowInfo.bounds)

        if let axWindow = axWindow {
            AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        }

        if let app = NSRunningApplication(processIdentifier: windowInfo.ownerPID) {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }
}
