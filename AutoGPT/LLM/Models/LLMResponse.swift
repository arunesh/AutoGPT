//
//  LLMResponse.swift
//  AutoGPT
//
//  Response model for LLM interactions
//

import Foundation

struct LLMResponse {
    let content: String
    let metadata: [String: Any]?
    let usage: TokenUsage?

    init(content: String, metadata: [String: Any]? = nil, usage: TokenUsage? = nil) {
        self.content = content
        self.metadata = metadata
        self.usage = usage
    }
}

struct TokenUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    init(promptTokens: Int, completionTokens: Int, totalTokens: Int) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}
