//
//  ObservabilityConfiguration.swift
//  AutoGPT
//
//  Configuration for observability and tracing
//

import Foundation

struct ObservabilityConfiguration: Codable {
    var enabled: Bool
    var endpoint: String
    var apiKey: String?

    var headers: [String: String] {
        var headers = [
            "Content-Type": "application/json"
        ]

        if let apiKey = apiKey {
            headers["Authorization"] = "Bearer \(apiKey)"
        }

        return headers
    }

    init(
        enabled: Bool = true,
        endpoint: String = "http://localhost:6006/v1/traces",
        apiKey: String? = nil
    ) {
        self.enabled = enabled
        self.endpoint = endpoint
        self.apiKey = apiKey
    }
}
