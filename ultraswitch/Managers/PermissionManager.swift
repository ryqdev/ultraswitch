//
//  PermissionManager.swift
//  ultraswitch
//

import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var hasScreenRecordingPermission = false

    private var monitoringTimer: Timer?

    private init() {
        checkPermissions()
    }

    var hasAllPermissions: Bool {
        hasAccessibilityPermission && hasScreenRecordingPermission
    }

    func checkPermissions() {
        hasAccessibilityPermission = checkAccessibilityPermission()
        Task {
            let screenPerm = await checkScreenRecordingPermissionAsync()
            self.hasScreenRecordingPermission = screenPerm
        }
    }

    func checkPermissionsAsync() async {
        hasAccessibilityPermission = checkAccessibilityPermission()
        hasScreenRecordingPermission = await checkScreenRecordingPermissionAsync()
    }

    func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func checkScreenRecordingPermissionAsync() async -> Bool {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return !content.windows.isEmpty
        } catch {
            return false
        }
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    func startPermissionMonitoring() {
        stopPermissionMonitoring()
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
    }

    func stopPermissionMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
}
