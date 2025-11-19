//
//  AutomationEngine.swift
//  AutoGPT
//
//  Engine for executing automation tasks based on LLM instructions
//

import Foundation

@MainActor
class AutomationEngine: ObservableObject {
    private let appController: AppController
    private let accessibility: AccessibilityManager

    @Published var isExecuting = false
    @Published var currentTask: AutomationTask?

    init(appController: AppController, accessibility: AccessibilityManager) {
        self.appController = appController
        self.accessibility = accessibility
    }

    /// Execute an automation task
    func executeTask(_ task: AutomationTask) async throws -> TaskResult {
        isExecuting = true
        currentTask = task
        defer {
            isExecuting = false
            currentTask = nil
        }

        var results: [String] = []

        for step in task.steps {
            let result = try await executeStep(step)
            results.append(result)
        }

        return TaskResult(
            success: true,
            message: "Task completed successfully",
            data: ["results": results.joined(separator: ", ")]
        )
    }

    private func executeStep(_ step: TaskStep) async throws -> String {
        switch step.action.lowercased() {
        case "launch":
            guard let bundleId = step.target else {
                throw AutomationError.missingTarget
            }
            try await appController.launchApp(bundleId)
            return "Launched \(bundleId)"

        case "quit":
            guard let bundleId = step.target else {
                throw AutomationError.missingTarget
            }
            try await appController.quitApp(bundleId)
            return "Quit \(bundleId)"

        case "focus":
            guard let bundleId = step.target else {
                throw AutomationError.missingTarget
            }
            try await appController.bringAppToFront(bundleId)
            return "Focused \(bundleId)"

        case "type":
            guard let text = step.parameters["text"] else {
                throw AutomationError.missingParameter("text")
            }
            try await accessibility.performAction(.type(text: text, element: nil))
            return "Typed text"

        case "press":
            guard let keyString = step.parameters["key"],
                  let key = Key(rawValue: keyString) else {
                throw AutomationError.invalidParameter("key")
            }

            let modifiers = parseModifiers(from: step.parameters["modifiers"])
            try await accessibility.performAction(.press(key: key, modifiers: modifiers))
            return "Pressed key \(keyString)"

        case "click":
            guard let x = step.parameters["x"],
                  let y = step.parameters["y"],
                  let xPos = Double(x),
                  let yPos = Double(y) else {
                throw AutomationError.invalidParameter("position")
            }

            let point = CGPoint(x: xPos, y: yPos)
            if let element = try accessibility.getElementAtPoint(point) {
                try await accessibility.performAction(.click(element: element))
                return "Clicked at (\(xPos), \(yPos))"
            } else {
                throw AutomationError.elementNotFound
            }

        case "wait":
            guard let duration = step.parameters["duration"],
                  let seconds = Double(duration) else {
                throw AutomationError.invalidParameter("duration")
            }

            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return "Waited \(seconds) seconds"

        default:
            throw AutomationError.unknownAction(step.action)
        }
    }

    private func parseModifiers(from string: String?) -> [Modifier] {
        guard let string = string else { return [] }

        let modifierStrings = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        var modifiers: [Modifier] = []

        for modString in modifierStrings {
            switch modString.lowercased() {
            case "command", "cmd":
                modifiers.append(.command)
            case "option", "alt":
                modifiers.append(.option)
            case "control", "ctrl":
                modifiers.append(.control)
            case "shift":
                modifiers.append(.shift)
            default:
                break
            }
        }

        return modifiers
    }

    /// Parse automation task from natural language (simple implementation)
    func parseTaskFromText(_ text: String) -> AutomationTask? {
        // This is a simplified parser
        // In production, the LLM would return structured JSON that we parse

        var steps: [TaskStep] = []

        // Simple pattern matching
        if text.lowercased().contains("open") || text.lowercased().contains("launch") {
            // Extract app name (simplified)
            if text.lowercased().contains("safari") {
                steps.append(TaskStep(action: "launch", target: "com.apple.Safari"))
            } else if text.lowercased().contains("notes") {
                steps.append(TaskStep(action: "launch", target: "com.apple.Notes"))
            }
        }

        if !steps.isEmpty {
            return AutomationTask(description: text, steps: steps)
        }

        return nil
    }
}

// MARK: - Errors

enum AutomationError: LocalizedError {
    case missingTarget
    case missingParameter(String)
    case invalidParameter(String)
    case unknownAction(String)
    case elementNotFound

    var errorDescription: String? {
        switch self {
        case .missingTarget:
            return "Missing target for action"
        case .missingParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidParameter(let param):
            return "Invalid parameter: \(param)"
        case .unknownAction(let action):
            return "Unknown action: \(action)"
        case .elementNotFound:
            return "UI element not found"
        }
    }
}
