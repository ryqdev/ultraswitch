//
//  HotkeyManager.swift
//  ultraswitch
//

import AppKit
import Carbon.HIToolbox

final class HotkeyManager {
    static let shared = HotkeyManager()

    var onSwitcherActivate: (() -> Void)?
    var onTabPressed: ((_ isShift: Bool) -> Void)?
    var onCommandReleased: (() -> Void)?
    var onEscapePressed: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isSwitcherActive = false

    private let tabKeyCode: CGKeyCode = 48
    private let escapeKeyCode: CGKeyCode = 53

    private init() {}

    func start() -> Bool {
        guard eventTap == nil else { return true }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleEvent(proxy: proxy, type: type, event: event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap. Accessibility permission may not be granted.")
            return false
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

        guard let runLoopSource = runLoopSource else {
            print("Failed to create run loop source")
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        print("HotkeyManager: Event tap started successfully")
        return true
    }

    func stop() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isSwitcherActive = false
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let isCommandPressed = flags.contains(.maskCommand)
        let isShiftPressed = flags.contains(.maskShift)

        switch type {
        case .keyDown:
            if keyCode == tabKeyCode && isCommandPressed {
                print("HotkeyManager: Cmd+Tab detected, isSwitcherActive=\(isSwitcherActive)")
                if !isSwitcherActive {
                    print("HotkeyManager: Calling onSwitcherActivate...")
                    isSwitcherActive = true
                    DispatchQueue.main.async {
                        self.onSwitcherActivate?()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.onTabPressed?(isShiftPressed)
                    }
                }
                return nil
            }

            if keyCode == escapeKeyCode && isSwitcherActive {
                DispatchQueue.main.async {
                    self.onEscapePressed?()
                }
                isSwitcherActive = false
                return nil
            }

        case .flagsChanged:
            if isSwitcherActive && !isCommandPressed {
                DispatchQueue.main.async {
                    self.onCommandReleased?()
                }
                isSwitcherActive = false
            }

        default:
            break
        }

        return Unmanaged.passRetained(event)
    }
}
