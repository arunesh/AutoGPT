//
//  LLMConfiguration.swift
//  AutoGPT
//
//  Configuration model for LLM providers
//

import Foundation

struct LLMConfiguration: Codable {
    var apiKey: String?
    var baseURL: String?
    var model: String
    var temperature: Double
    var maxTokens: Int?
    var systemPrompt: String?

    init(
        apiKey: String? = nil,
        baseURL: String? = nil,
        model: String = "gpt-4",
        temperature: Double = 0.7,
        maxTokens: Int? = 4096,
        systemPrompt: String? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
    }
}
