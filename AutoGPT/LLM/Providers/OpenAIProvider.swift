//
//  OpenAIProvider.swift
//  AutoGPT
//
//  OpenAI LLM provider implementation
//

import Foundation

class OpenAIProvider: LLMProvider {
    let name = "OpenAI"
    var configuration: LLMConfiguration

    private var currentTask: Task<Void, Never>?

    init(configuration: LLMConfiguration) {
        self.configuration = configuration
    }

    func sendMessage(_ message: Message, context: [Message]) async throws -> LLMResponse {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw LLMError.invalidAPIKey
        }

        let baseURL = configuration.baseURL ?? "https://api.openai.com/v1"
        let url = URL(string: "\(baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let messages = buildMessages(newMessage: message, context: context)
        let requestBody: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "temperature": configuration.temperature,
            "max_tokens": configuration.maxTokens ?? 4096
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw LLMError.rateLimitExceeded
            }
            throw LLMError.networkError(NSError(domain: "OpenAI", code: httpResponse.statusCode))
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        let usage = parseUsage(from: json)

        return LLMResponse(content: content, metadata: json, usage: usage)
    }

    func streamMessage(_ message: Message, context: [Message]) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            currentTask = Task {
                do {
                    guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
                        throw LLMError.invalidAPIKey
                    }

                    let baseURL = configuration.baseURL ?? "https://api.openai.com/v1"
                    let url = URL(string: "\(baseURL)/chat/completions")!

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

                    let messages = buildMessages(newMessage: message, context: context)
                    let requestBody: [String: Any] = [
                        "model": configuration.model,
                        "messages": messages,
                        "temperature": configuration.temperature,
                        "max_tokens": configuration.maxTokens ?? 4096,
                        "stream": true
                    ]

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

                        if data == "[DONE]" {
                            continuation.finish()
                            break
                        }

                        if let jsonData = data.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            continuation.yield(content)
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

    private func buildMessages(newMessage: Message, context: [Message]) -> [[String: String]] {
        var messages: [[String: String]] = []

        // Add system prompt if configured
        if let systemPrompt = configuration.systemPrompt {
            messages.append(["role": "system", "content": systemPrompt])
        }

        // Add context messages
        for msg in context {
            messages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        // Add new message
        messages.append(["role": newMessage.role.rawValue, "content": newMessage.content])

        return messages
    }

    private func parseUsage(from json: [String: Any]?) -> TokenUsage? {
        guard let usage = json?["usage"] as? [String: Any],
              let promptTokens = usage["prompt_tokens"] as? Int,
              let completionTokens = usage["completion_tokens"] as? Int,
              let totalTokens = usage["total_tokens"] as? Int else {
            return nil
        }

        return TokenUsage(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: totalTokens
        )
    }
}
