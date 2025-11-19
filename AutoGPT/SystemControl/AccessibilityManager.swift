//
//  AccessibilityManager.swift
//  AutoGPT
//
//  Manager for macOS Accessibility APIs
//

import Foundation
import ApplicationServices
import Cocoa

class AccessibilityManager {

    // MARK: - Permissions

    /// Request accessibility permissions
    func requestAccessibilityPermissions() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Check if accessibility permissions are granted
    var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    // MARK: - Application Observation

    /// Get list of running applications
    func observeApplications() -> [NSRunningApplication] {
        return NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular
        }
    }

    /// Get UI elements of an application
    func getUIElements(for app: NSRunningApplication) throws -> [AXUIElement] {
        guard let pid = app.processIdentifier as pid_t? else {
            throw AccessibilityError.invalidApplication
        }

        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsRef
        )

        guard result == .success,
              let windows = windowsRef as? [AXUIElement] else {
            throw AccessibilityError.failedToGetElements
        }

        return windows
    }

    /// Get element at specific point on screen
    func getElementAtPoint(_ point: CGPoint) throws -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            systemWide,
            Float(point.x),
            Float(point.y),
            &element
        )

        guard result == .success else {
            return nil
        }

        return element
    }

    // MARK: - Actions

    /// Perform an accessibility action
    func performAction(_ action: AccessibilityAction) async throws {
        switch action {
        case .click(let element):
            try clickElement(element)

        case .type(let text, let element):
            try typeText(text, in: element)

        case .press(let key, let modifiers):
            try pressKey(key, modifiers: modifiers)

        case .focus(let element):
            try focusElement(element)

        case .setValue(let element, let value):
            try setElementValue(element, value: value)
        }
    }

    private func clickElement(_ element: AXUIElement) throws {
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        guard result == .success else {
            throw AccessibilityError.actionFailed
        }
    }

    private func typeText(_ text: String, in element: AXUIElement?) throws {
        if let element = element {
            // Set value directly if element is provided
            var value: CFTypeRef = text as CFString
            let result = AXUIElementSetAttributeValue(
                element,
                kAXValueAttribute as CFString,
                value
            )

            guard result == .success else {
                throw AccessibilityError.actionFailed
            }
        } else {
            // Type using keyboard events
            for char in text {
                try typeCharacter(char)
            }
        }
    }

    private func typeCharacter(_ char: Character) throws {
        let string = String(char)
        guard let unicodeScalar = string.unicodeScalars.first else { return }

        let keyCode: CGKeyCode = 0 // Key code is optional for character input

        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: true
        ) else {
            throw AccessibilityError.failedToCreateEvent
        }

        keyDownEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [unicodeScalar.value])
        keyDownEvent.post(tap: .cghidEventTap)

        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: false
        ) else {
            throw AccessibilityError.failedToCreateEvent
        }

        keyUpEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [unicodeScalar.value])
        keyUpEvent.post(tap: .cghidEventTap)
    }

    private func pressKey(_ key: Key, modifiers: [Modifier]) throws {
        let flags = modifiers.reduce(CGEventFlags()) { result, modifier in
            result.union(modifier.cgFlag)
        }

        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
            throw AccessibilityError.failedToCreateEvent
        }

        keyDownEvent.flags = flags
        keyDownEvent.keyboardSetUnicodeString(
            stringLength: key.rawValue.count,
            unicodeString: Array(key.rawValue.utf16)
        )
        keyDownEvent.post(tap: .cghidEventTap)

        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            throw AccessibilityError.failedToCreateEvent
        }

        keyUpEvent.flags = flags
        keyUpEvent.keyboardSetUnicodeString(
            stringLength: key.rawValue.count,
            unicodeString: Array(key.rawValue.utf16)
        )
        keyUpEvent.post(tap: .cghidEventTap)
    }

    private func focusElement(_ element: AXUIElement) throws {
        let result = AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            true as CFBoolean
        )

        guard result == .success else {
            throw AccessibilityError.actionFailed
        }
    }

    private func setElementValue(_ element: AXUIElement, value: Any) throws {
        var cfValue: CFTypeRef

        if let stringValue = value as? String {
            cfValue = stringValue as CFString
        } else if let numberValue = value as? NSNumber {
            cfValue = numberValue
        } else {
            throw AccessibilityError.invalidValue
        }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            cfValue
        )

        guard result == .success else {
            throw AccessibilityError.actionFailed
        }
    }

    // MARK: - Element Information

    /// Get element attributes
    func getElementAttributes(_ element: AXUIElement) -> [String: Any] {
        var attributes: [String: Any] = [:]

        // Get role
        if let role = getAttributeValue(element, attribute: kAXRoleAttribute) as? String {
            attributes["role"] = role
        }

        // Get title
        if let title = getAttributeValue(element, attribute: kAXTitleAttribute) as? String {
            attributes["title"] = title
        }

        // Get value
        if let value = getAttributeValue(element, attribute: kAXValueAttribute) {
            attributes["value"] = value
        }

        // Get position
        if let position = getAttributeValue(element, attribute: kAXPositionAttribute) as? CGPoint {
            attributes["position"] = position
        }

        // Get size
        if let size = getAttributeValue(element, attribute: kAXSizeAttribute) as? CGSize {
            attributes["size"] = size
        }

        return attributes
    }

    private func getAttributeValue(_ element: AXUIElement, attribute: String) -> Any? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        guard result == .success else {
            return nil
        }

        return value
    }
}

// MARK: - Errors

enum AccessibilityError: LocalizedError {
    case notAuthorized
    case invalidApplication
    case failedToGetElements
    case actionFailed
    case failedToCreateEvent
    case invalidValue

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Accessibility permissions not granted"
        case .invalidApplication:
            return "Invalid application"
        case .failedToGetElements:
            return "Failed to get UI elements"
        case .actionFailed:
            return "Failed to perform action"
        case .failedToCreateEvent:
            return "Failed to create keyboard event"
        case .invalidValue:
            return "Invalid value for element"
        }
    }
}
