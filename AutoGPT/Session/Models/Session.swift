//
//  Session.swift
//  AutoGPT
//
//  Session model for conversation history
//

import Foundation

struct Session: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [Message]
    let createdAt: Date
    var updatedAt: Date
    var metadata: SessionMetadata

    init(
        id: UUID = UUID(),
        title: String = "New Session",
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: SessionMetadata = SessionMetadata()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }

    mutating func addMessage(_ message: Message) {
        messages.append(message)
        updatedAt = Date()
        metadata.messageCount = messages.count
    }
}

struct SessionMetadata: Codable, Equatable {
    var totalDuration: TimeInterval
    var messageCount: Int
    var voiceInteractionCount: Int
    var automationTasksExecuted: Int

    init(
        totalDuration: TimeInterval = 0,
        messageCount: Int = 0,
        voiceInteractionCount: Int = 0,
        automationTasksExecuted: Int = 0
    ) {
        self.totalDuration = totalDuration
        self.messageCount = messageCount
        self.voiceInteractionCount = voiceInteractionCount
        self.automationTasksExecuted = automationTasksExecuted
    }
}
