//
//  WindowInfo.swift
//  ultraswitch
//

import AppKit
import ApplicationServices

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let windowTitle: String
    let bounds: CGRect
    var thumbnail: NSImage?
    var axWindow: AXUIElement?

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var appIcon: NSImage? {
        guard let app = NSRunningApplication(processIdentifier: ownerPID) else {
            return nil
        }
        return app.icon
    }

    var displayTitle: String {
        if windowTitle.isEmpty {
            return ownerName
        }
        return windowTitle
    }
}
