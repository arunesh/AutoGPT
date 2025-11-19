//
//  AppController.swift
//  AutoGPT
//
//  Application control and window management
//

import Foundation
import Cocoa
import ApplicationServices

class AppController {
    private let accessibility: AccessibilityManager

    init(accessibility: AccessibilityManager) {
        self.accessibility = accessibility
    }

    // MARK: - App Launching and Control

    /// Launch an application by bundle identifier
    func launchApp(_ bundleIdentifier: String) async throws {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AppControlError.applicationNotFound
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    /// Quit an application by bundle identifier
    func quitApp(_ bundleIdentifier: String) async throws {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            throw AppControlError.applicationNotRunning
        }

        let terminated = app.terminate()
        if !terminated {
            // Force quit if graceful termination failed
            _ = app.forceTerminate()
        }
    }

    /// Bring application to front
    func bringAppToFront(_ bundleIdentifier: String) async throws {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            throw AppControlError.applicationNotRunning
        }

        let activated = app.activate(options: .activateIgnoringOtherApps)
        if !activated {
            throw AppControlError.failedToActivate
        }
    }

    /// Get the currently active application
    func getActiveApp() -> NSRunningApplication? {
        return NSWorkspace.shared.frontmostApplication
    }

    // MARK: - Window Management

    /// Get the active window
    func getActiveWindow() -> AXUIElement? {
        guard let activeApp = NSWorkspace.shared.frontmostApplication,
              let pid = activeApp.processIdentifier as pid_t? else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard result == .success,
              let window = focusedWindow else {
            return nil
        }

        return (window as! AXUIElement)
    }

    /// Get list of all windows
    func getWindowList() -> [WindowInfo] {
        var windows: [WindowInfo] = []

        let runningApps = accessibility.observeApplications()

        for app in runningApps {
            guard let bundleIdentifier = app.bundleIdentifier,
                  let pid = app.processIdentifier as pid_t? else {
                continue
            }

            let appElement = AXUIElementCreateApplication(pid)

            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                appElement,
                kAXWindowsAttribute as CFString,
                &windowsRef
            )

            guard result == .success,
                  let axWindows = windowsRef as? [AXUIElement] else {
                continue
            }

            for window in axWindows {
                if let windowInfo = getWindowInfo(window, bundleIdentifier: bundleIdentifier) {
                    windows.append(windowInfo)
                }
            }
        }

        return windows
    }

    private func getWindowInfo(_ window: AXUIElement, bundleIdentifier: String) -> WindowInfo? {
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)

        var positionRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)

        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

        var position = CGPoint.zero
        var size = CGSize.zero

        if let positionValue = positionRef {
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        }

        if let sizeValue = sizeRef {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        }

        return WindowInfo(
            title: (title as? String) ?? "Untitled",
            bundleIdentifier: bundleIdentifier,
            position: position,
            size: size
        )
    }

    /// Move and resize window
    func moveWindow(_ window: AXUIElement, to position: CGPoint, size: CGSize) throws {
        var positionValue = position
        var sizeValue = size

        let positionRef = AXValueCreate(.cgPoint, &positionValue)!
        let sizeRef = AXValueCreate(.cgSize, &sizeValue)!

        var result = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionRef
        )

        guard result == .success else {
            throw AppControlError.failedToMoveWindow
        }

        result = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeRef
        )

        guard result == .success else {
            throw AppControlError.failedToResizeWindow
        }
    }
}

// MARK: - Errors

enum AppControlError: LocalizedError {
    case applicationNotFound
    case applicationNotRunning
    case failedToActivate
    case failedToMoveWindow
    case failedToResizeWindow

    var errorDescription: String? {
        switch self {
        case .applicationNotFound:
            return "Application not found"
        case .applicationNotRunning:
            return "Application is not running"
        case .failedToActivate:
            return "Failed to activate application"
        case .failedToMoveWindow:
            return "Failed to move window"
        case .failedToResizeWindow:
            return "Failed to resize window"
        }
    }
}
