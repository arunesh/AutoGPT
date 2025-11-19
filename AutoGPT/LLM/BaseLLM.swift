//
//  BaseLLM.swift
//  AutoGPT
//
//  Base protocol for all LLM provider implementations
//

import Foundation

/// Base protocol for all LLM implementations
protocol LLMProvider {
    var name: String { get }
    var configuration: LLMConfiguration { get set }

    func sendMessage(_ message: Message, context: [Message]) async throws -> LLMResponse
    func streamMessage(_ message: Message, context: [Message]) -> AsyncThrowingStream<String, Error>
    func cancelRequest()
}

/// Default implementation for streaming (can be overridden by providers)
extension LLMProvider {
    func streamMessage(_ message: Message, context: [Message]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await sendMessage(message, context: context)
                    continuation.yield(response.content)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func cancelRequest() {
        // Default implementation - providers can override
    }
}

/// Provider types available
enum ProviderType: String, CaseIterable, Codable {
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Gemini"
    case litellm = "LiteLLM"
}

/// LLM specific errors
enum LLMError: LocalizedError {
    case invalidAPIKey
    case invalidConfiguration
    case networkError(Error)
    case invalidResponse
    case rateLimitExceeded
    case contextLengthExceeded
    case modelNotAvailable

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key provided"
        case .invalidConfiguration:
            return "Invalid LLM configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from LLM provider"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .contextLengthExceeded:
            return "Context length exceeded"
        case .modelNotAvailable:
            return "Requested model is not available"
        }
    }
}

/// Conversation context for LLM requests
struct ConversationContext {
    let messages: [Message]
    let systemPrompt: String?

    init(messages: [Message], systemPrompt: String? = nil) {
        self.messages = messages
        self.systemPrompt = systemPrompt
    }
}
