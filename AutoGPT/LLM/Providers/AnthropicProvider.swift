//
//  AnthropicProvider.swift
//  AutoGPT
//
//  Anthropic Claude LLM provider implementation
//

import Foundation

class AnthropicProvider: LLMProvider {
    let name = "Anthropic"
    var configuration: LLMConfiguration

    private var currentTask: Task<Void, Never>?

    init(configuration: LLMConfiguration) {
        self.configuration = configuration
    }

    func sendMessage(_ message: Message, context: [Message]) async throws -> LLMResponse {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw LLMError.invalidAPIKey
        }

        let baseURL = configuration.baseURL ?? "https://api.anthropic.com/v1"
        let url = URL(string: "\(baseURL)/messages")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let messages = buildMessages(newMessage: message, context: context)
        var requestBody: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "max_tokens": configuration.maxTokens ?? 4096
        ]

        // Add system prompt if configured
        if let systemPrompt = configuration.systemPrompt {
            requestBody["system"] = systemPrompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw LLMError.rateLimitExceeded
            }
            throw LLMError.networkError(NSError(domain: "Anthropic", code: httpResponse.statusCode))
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        let usage = parseUsage(from: json)

        return LLMResponse(content: text, metadata: json, usage: usage)
    }

    func streamMessage(_ message: Message, context: [Message]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            currentTask = Task {
                do {
                    guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
                        throw LLMError.invalidAPIKey
                    }

                    let baseURL = configuration.baseURL ?? "https://api.anthropic.com/v1"
                    let url = URL(string: "\(baseURL)/messages")!

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    let messages = buildMessages(newMessage: message, context: context)
                    var requestBody: [String: Any] = [
                        "model": configuration.model,
                        "messages": messages,
                        "max_tokens": configuration.maxTokens ?? 4096,
                        "stream": true
                    ]

                    if let systemPrompt = configuration.systemPrompt {
                        requestBody["system"] = systemPrompt
                    }

                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw LLMError.invalidResponse
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let data = line.dropFirst(6)

                        if let jsonData = data.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

                            if json["type"] as? String == "content_block_delta",
                               let delta = json["delta"] as? [String: Any],
                               let text = delta["text"] as? String {
                                continuation.yield(text)
                            } else if json["type"] as? String == "message_stop" {
                                continuation.finish()
                                break
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func cancelRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func buildMessages(newMessage: Message, context: [Message]) -> [[String: Any]] {
        var messages: [[String: Any]] = []

        // Add context messages (exclude system messages as they go in separate field)
        for msg in context where msg.role != .system {
            messages.append([
                "role": msg.role.rawValue,
                "content": msg.content
            ])
        }

        // Add new message
        if newMessage.role != .system {
            messages.append([
                "role": newMessage.role.rawValue,
                "content": newMessage.content
            ])
        }

        return messages
    }

    private func parseUsage(from json: [String: Any]?) -> TokenUsage? {
        guard let usage = json?["usage"] as? [String: Any],
              let inputTokens = usage["input_tokens"] as? Int,
              let outputTokens = usage["output_tokens"] as? Int else {
            return nil
        }

        return TokenUsage(
            promptTokens: inputTokens,
            completionTokens: outputTokens,
            totalTokens: inputTokens + outputTokens
        )
    }
}
