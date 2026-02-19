//
//  PermissionRequestView.swift
//  ultraswitch
//

import SwiftUI

struct PermissionRequestView: View {
    @ObservedObject var permissionManager = PermissionManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Text("UltraSwitch")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Permissions Required")
                .font(.title2)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                PermissionRow(
                    title: "Accessibility",
                    description: "Required to intercept Cmd+Tab and switch windows",
                    isGranted: permissionManager.hasAccessibilityPermission,
                    action: {
                        permissionManager.requestAccessibilityPermission()
                    }
                )

                PermissionRow(
                    title: "Screen Recording",
                    description: "Required to capture window thumbnails",
                    isGranted: permissionManager.hasScreenRecordingPermission,
                    action: {
                        permissionManager.openScreenRecordingSettings()
                    }
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)

            if permissionManager.hasAllPermissions {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("All permissions granted!")
                        .font(.headline)
                    Text("UltraSwitch is ready. Press Cmd+Tab to switch windows.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)
            }

            Spacer()
        }
        .padding(32)
        .frame(width: 450, height: 400)
        .onAppear {
            permissionManager.startPermissionMonitoring()
        }
        .onDisappear {
            permissionManager.stopPermissionMonitoring()
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(isGranted ? .green : .red)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isGranted {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
