//
//  ObservabilityService.swift
//  AutoGPT
//
//  Observability service with OTLP tracing support
//  Note: Full OpenTelemetry integration requires the OpenTelemetry SDK
//  This is a simplified implementation that can be extended
//

import Foundation

// MARK: - Span Protocol

protocol Span: AnyObject {
    var spanId: String { get }
    var startTime: Date { get }
    var attributes: [String: Any] { get set }

    func setAttribute(key: String, value: Any)
}

class SimpleSpan: Span {
    let spanId: String
    let startTime: Date
    var attributes: [String: Any]
    var endTime: Date?

    init(spanId: String = UUID().uuidString, attributes: [String: Any] = [:]) {
        self.spanId = spanId
        self.startTime = Date()
        self.attributes = attributes
    }

    func setAttribute(key: String, value: Any) {
        attributes[key] = value
    }
}

// MARK: - Observability Service Protocol

protocol ObservabilityService {
    func startSpan(name: String, attributes: [String: Any]?) -> Span
    func endSpan(_ span: Span)
    func recordEvent(_ event: String, attributes: [String: Any]?)
    func recordException(_ error: Error, span: Span?)
}

// MARK: - Simple OTLP Observability Service

class SimpleOTLPObservabilityService: ObservabilityService {
    private let configuration: ObservabilityConfiguration
    private var spans: [String: SimpleSpan] = [:]
    private let queue = DispatchQueue(label: "com.autogpt.observability")

    init(configuration: ObservabilityConfiguration) {
        self.configuration = configuration
    }

    func startSpan(name: String, attributes: [String: Any]? = nil) -> Span {
        guard configuration.enabled else {
            return SimpleSpan(attributes: attributes ?? [:])
        }

        var spanAttributes = attributes ?? [:]
        spanAttributes["span.name"] = name

        let span = SimpleSpan(attributes: spanAttributes)

        queue.async {
            self.spans[span.spanId] = span
        }

        return span
    }

    func endSpan(_ span: Span) {
        guard configuration.enabled,
              let simpleSpan = span as? SimpleSpan else {
            return
        }

        simpleSpan.endTime = Date()

        // Export span to OTLP endpoint
        Task {
            await exportSpan(simpleSpan)
        }

        queue.async {
            self.spans.removeValue(forKey: span.spanId)
        }
    }

    func recordEvent(_ event: String, attributes: [String: Any]? = nil) {
        guard configuration.enabled else { return }

        let eventData: [String: Any] = [
            "event": event,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "attributes": attributes ?? [:]
        ]

        Task {
            await sendEvent(eventData)
        }
    }

    func recordException(_ error: Error, span: Span? = nil) {
        guard configuration.enabled else { return }

        var attributes: [String: Any] = [
            "exception.type": String(describing: type(of: error)),
            "exception.message": error.localizedDescription
        ]

        if let span = span {
            attributes["span.id"] = span.spanId
        }

        recordEvent("exception", attributes: attributes)

        if let span = span as? SimpleSpan {
            span.setAttribute(key: "error", value: true)
            span.setAttribute(key: "exception.type", value: String(describing: type(of: error)))
            span.setAttribute(key: "exception.message", value: error.localizedDescription)
        }
    }

    private func exportSpan(_ span: SimpleSpan) async {
        let duration = span.endTime?.timeIntervalSince(span.startTime) ?? 0

        let spanData: [String: Any] = [
            "span_id": span.spanId,
            "start_time": ISO8601DateFormatter().string(from: span.startTime),
            "end_time": ISO8601DateFormatter().string(from: span.endTime ?? Date()),
            "duration_ms": duration * 1000,
            "attributes": span.attributes
        ]

        await sendTrace(spanData)
    }

    private func sendTrace(_ spanData: [String: Any]) async {
        guard let url = URL(string: configuration.endpoint) else {
            print("Invalid observability endpoint: \(configuration.endpoint)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        for (key, value) in configuration.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Wrap span in OTLP format
        let otlpData: [String: Any] = [
            "resourceSpans": [
                [
                    "resource": [
                        "attributes": [
                            ["key": "service.name", "value": ["stringValue": "AutoGPT"]]
                        ]
                    ],
                    "scopeSpans": [
                        [
                            "spans": [spanData]
                        ]
                    ]
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: otlpData)

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    print("Trace exported successfully")
                } else {
                    print("Failed to export trace: HTTP \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("Error exporting trace: \(error.localizedDescription)")
        }
    }

    private func sendEvent(_ eventData: [String: Any]) async {
        // Similar to sendTrace but for events
        // Implementation can be added based on specific event tracking needs
    }
}

// MARK: - No-Op Observability Service

/// No-op implementation when observability is disabled
class NoOpObservabilityService: ObservabilityService {
    func startSpan(name: String, attributes: [String: Any]? = nil) -> Span {
        return SimpleSpan(attributes: attributes ?? [:])
    }

    func endSpan(_ span: Span) {
        // No-op
    }

    func recordEvent(_ event: String, attributes: [String: Any]? = nil) {
        // No-op
    }

    func recordException(_ error: Error, span: Span? = nil) {
        // No-op
    }
}
