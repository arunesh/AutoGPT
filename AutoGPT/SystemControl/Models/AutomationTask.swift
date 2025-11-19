//
//  AutomationTask.swift
//  AutoGPT
//
//  Models for automation tasks
//

import Foundation

struct AutomationTask: Codable, Identifiable {
    let id: UUID
    let description: String
    let steps: [TaskStep]

    init(id: UUID = UUID(), description: String, steps: [TaskStep]) {
        self.id = id
        self.description = description
        self.steps = steps
    }
}

struct TaskStep: Codable, Identifiable {
    let id: UUID
    let action: String
    let target: String?
    let parameters: [String: String]

    init(id: UUID = UUID(), action: String, target: String? = nil, parameters: [String: String] = [:]) {
        self.id = id
        self.action = action
        self.target = target
        self.parameters = parameters
    }
}

struct TaskResult: Codable {
    let success: Bool
    let message: String
    let data: [String: String]?

    init(success: Bool, message: String, data: [String: String]? = nil) {
        self.success = success
        self.message = message
        self.data = data
    }
}

struct WindowInfo: Codable, Identifiable {
    let id: UUID
    let title: String
    let bundleIdentifier: String
    let position: CGPoint
    let size: CGSize

    init(id: UUID = UUID(), title: String, bundleIdentifier: String, position: CGPoint, size: CGSize) {
        self.id = id
        self.title = title
        self.bundleIdentifier = bundleIdentifier
        self.position = position
        self.size = size
    }
}
