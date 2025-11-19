//
//  AccessibilityAction.swift
//  AutoGPT
//
//  Models for accessibility actions
//

import Foundation
import ApplicationServices

enum AccessibilityAction {
    case click(element: AXUIElement)
    case type(text: String, element: AXUIElement? = nil)
    case press(key: Key, modifiers: [Modifier] = [])
    case focus(element: AXUIElement)
    case setValue(element: AXUIElement, value: Any)
}

enum Key: String {
    case enter = "\r"
    case tab = "\t"
    case escape = "\u{1B}"
    case space = " "
    case delete = "\u{7F}"
    case up = "\u{F700}"
    case down = "\u{F701}"
    case left = "\u{F702}"
    case right = "\u{F703}"
}

enum Modifier {
    case command
    case option
    case control
    case shift

    var cgFlag: CGEventFlags {
        switch self {
        case .command: return .maskCommand
        case .option: return .maskAlternate
        case .control: return .maskControl
        case .shift: return .maskShift
        }
    }
}
