//
//  Message.swift
//  AutoGPT
//
//  Message model for LLM conversations
//

import Foundation

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
