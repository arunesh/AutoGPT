//
//  LLMManager.swift
//  AutoGPT
//
//  Manager for LLM providers with observability integration
//

import Foundation

@MainActor
class LLMManager: ObservableObject {
    @Published var currentProvider: LLMProvider
    @Published var isProcessing: Bool = false

    private let observability: ObservabilityService?

    init(provider: LLMProvider, observability: ObservabilityService? = nil) {
        self.currentProvider = provider
        self.observability = observability
    }

    /// Switch to a different LLM provider
    func switchProvider(_ providerType: ProviderType, configuration: LLMConfiguration) {
        currentProvider = Self.createProvider(type: providerType, configuration: configuration)
    }

    /// Send a message to the LLM with context
    func sendMessage(_ message: Message, context: [Message]) async throws -> LLMResponse {
        isProcessing = true
        defer { isProcessing = false }

        // Start observability span
        let span = observability?.startSpan(
            name: "llm.request",
            attributes: [
                "llm.provider": currentProvider.name,
                "llm.model": currentProvider.configuration.model,
                "llm.message.role": message.role.rawValue,
                "llm.message.length": message.content.count
            ]
        )

        do {
            let response = try await currentProvider.sendMessage(message, context: context)

            // Record response metrics
            if let span = span {
                span.setAttribute(key: "llm.response.length", value: response.content.count)
                if let usage = response.usage {
                    span.setAttribute(key: "llm.usage.prompt_tokens", value: usage.promptTokens)
                    span.setAttribute(key: "llm.usage.completion_tokens", value: usage.completionTokens)
                    span.setAttribute(key: "llm.usage.total_tokens", value: usage.totalTokens)
                }
                observability?.endSpan(span)
            }

            return response
        } catch {
            // Record error
            if let span = span {
                observability?.recordException(error, span: span)
                observability?.endSpan(span)
            }
            throw error
        }
    }

    /// Stream a message response from the LLM
    func streamMessage(_ message: Message, context: [Message]) -> AsyncThrowingStream<String, Error> {
        let provider = currentProvider
        let observabilityService = observability

        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                isProcessing = true

                let span = observabilityService?.startSpan(
                    name: "llm.stream",
                    attributes: [
                        "llm.provider": provider.name,
                        "llm.model": provider.configuration.model,
                        "llm.message.role": message.role.rawValue
                    ]
                )

                do {
                    for try await chunk in provider.streamMessage(message, context: context) {
                        continuation.yield(chunk)
                    }

                    if let span = span {
                        observabilityService?.endSpan(span)
                    }

                    continuation.finish()
                } catch {
                    if let span = span {
                        observabilityService?.recordException(error, span: span)
                        observabilityService?.endSpan(span)
                    }
                    continuation.finish(throwing: error)
                }

                isProcessing = false
            }
        }
    }

    /// Cancel the current LLM request
    func cancelRequest() {
        currentProvider.cancelRequest()
        isProcessing = false
    }

    /// Factory method to create providers
    static func createProvider(type: ProviderType, configuration: LLMConfiguration) -> LLMProvider {
        switch type {
        case .openai:
            return OpenAIProvider(configuration: configuration)
        case .anthropic:
            return AnthropicProvider(configuration: configuration)
        case .gemini:
            return GeminiProvider(configuration: configuration)
        case .litellm:
            return LiteLLMProvider(configuration: configuration)
        }
    }
}
