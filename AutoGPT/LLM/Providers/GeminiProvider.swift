//
//  GeminiProvider.swift
//  AutoGPT
//
//  Google Gemini LLM provider implementation
//

import Foundation

class GeminiProvider: LLMProvider {
    let name = "Gemini"
    var configuration: LLMConfiguration

    private var currentTask: Task<Void, Never>?

    init(configuration: LLMConfiguration) {
        self.configuration = configuration
    }

    func sendMessage(_ message: Message, context: [Message]) async throws -> LLMResponse {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw LLMError.invalidAPIKey
        }

        let baseURL = configuration.baseURL ?? "https://generativelanguage.googleapis.com/v1beta"
        let model = configuration.model
        let url = URL(string: "\(baseURL)/models/\(model):generateContent?key=\(apiKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let contents = buildContents(newMessage: message, context: context)
        var requestBody: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "temperature": configuration.temperature,
                "maxOutputTokens": configuration.maxTokens ?? 4096
            ]
        ]

        // Add system instruction if configured
        if let systemPrompt = configuration.systemPrompt {
            requestBody["systemInstruction"] = [
                "parts": [["text": systemPrompt]]
            ]
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
            throw LLMError.networkError(NSError(domain: "Gemini", code: httpResponse.statusCode))
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let candidates = json?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
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

                    let baseURL = configuration.baseURL ?? "https://generativelanguage.googleapis.com/v1beta"
                    let model = configuration.model
                    let url = URL(string: "\(baseURL)/models/\(model):streamGenerateContent?key=\(apiKey)")!

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let contents = buildContents(newMessage: message, context: context)
                    var requestBody: [String: Any] = [
                        "contents": contents,
                        "generationConfig": [
                            "temperature": configuration.temperature,
                            "maxOutputTokens": configuration.maxTokens ?? 4096
                        ]
                    ]

                    if let systemPrompt = configuration.systemPrompt {
                        requestBody["systemInstruction"] = [
                            "parts": [["text": systemPrompt]]
                        ]
                    }

                    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw LLMError.invalidResponse
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        guard !line.isEmpty else { continue }

                        if let jsonData = line.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let candidates = json["candidates"] as? [[String: Any]],
                           let content = candidates.first?["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]],
                           let text = parts.first?["text"] as? String {
                            continuation.yield(text)
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

    private func buildContents(newMessage: Message, context: [Message]) -> [[String: Any]] {
        var contents: [[String: Any]] = []

        // Gemini uses "user" and "model" roles (not "assistant")
        let roleMapping: [MessageRole: String] = [
            .user: "user",
            .assistant: "model",
            .system: "user" // System messages converted to user messages
        ]

        // Add context messages
        for msg in context {
            contents.append([
                "role": roleMapping[msg.role] ?? "user",
                "parts": [["text": msg.content]]
            ])
        }

        // Add new message
        contents.append([
            "role": roleMapping[newMessage.role] ?? "user",
            "parts": [["text": newMessage.content]]
        ])

        return contents
    }

    private func parseUsage(from json: [String: Any]?) -> TokenUsage? {
        guard let usageMetadata = json?["usageMetadata"] as? [String: Any],
              let promptTokens = usageMetadata["promptTokenCount"] as? Int,
              let candidatesTokens = usageMetadata["candidatesTokenCount"] as? Int else {
            return nil
        }

        return TokenUsage(
            promptTokens: promptTokens,
            completionTokens: candidatesTokens,
            totalTokens: promptTokens + candidatesTokens
        )
    }
}
