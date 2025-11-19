//
//  AppConfiguration.swift
//  AutoGPT
//
//  Application-wide configuration management
//

import Foundation

@MainActor
class AppConfiguration: ObservableObject {
    @Published var llmProvider: ProviderType
    @Published var llmConfiguration: LLMConfiguration
    @Published var observabilityConfiguration: ObservabilityConfiguration
    @Published var voiceSettings: VoiceSettings

    private let userDefaults = UserDefaults.standard
    private let configKey = "app_configuration"

    init() {
        // Load saved configuration or use defaults
        if let data = userDefaults.data(forKey: configKey),
           let config = try? JSONDecoder().decode(SavedConfiguration.self, from: data) {
            self.llmProvider = config.llmProvider
            self.llmConfiguration = config.llmConfiguration
            self.observabilityConfiguration = config.observabilityConfiguration
            self.voiceSettings = config.voiceSettings
        } else {
            // Default configuration
            self.llmProvider = .anthropic
            self.llmConfiguration = Self.defaultLLMConfiguration()
            self.observabilityConfiguration = Self.defaultObservabilityConfiguration()
            self.voiceSettings = Self.defaultVoiceSettings()
        }
    }

    /// Save current configuration
    func save() {
        let config = SavedConfiguration(
            llmProvider: llmProvider,
            llmConfiguration: llmConfiguration,
            observabilityConfiguration: observabilityConfiguration,
            voiceSettings: voiceSettings
        )

        if let data = try? JSONEncoder().encode(config) {
            userDefaults.set(data, forKey: configKey)
        }
    }

    /// Reset to default configuration
    func reset() {
        llmProvider = .anthropic
        llmConfiguration = Self.defaultLLMConfiguration()
        observabilityConfiguration = Self.defaultObservabilityConfiguration()
        voiceSettings = Self.defaultVoiceSettings()
        save()
    }

    // MARK: - Default Configurations

    static func defaultLLMConfiguration() -> LLMConfiguration {
        return LLMConfiguration(
            apiKey: nil,
            baseURL: nil,
            model: "claude-3-5-sonnet-20241022",
            temperature: 0.7,
            maxTokens: 4096,
            systemPrompt: """
            You are AutoGPT, an AI assistant running on macOS. You can help users by:
            - Answering questions and providing information
            - Controlling desktop applications through accessibility APIs
            - Executing tasks and automation on their behalf
            - Managing files and system operations

            Always confirm potentially destructive actions before executing them.
            Be helpful, accurate, and respectful of user privacy and system security.
            """
        )
    }

    static func defaultObservabilityConfiguration() -> ObservabilityConfiguration {
        return ObservabilityConfiguration(
            enabled: true,
            endpoint: "http://localhost:6006/v1/traces",
            apiKey: nil
        )
    }

    static func defaultVoiceSettings() -> VoiceSettings {
        return VoiceSettings(
            voiceName: "com.apple.voice.enhanced.en-US.Samantha",
            speechRate: 0.5,
            autoSpeak: true
        )
    }
}

// MARK: - Saved Configuration

private struct SavedConfiguration: Codable {
    let llmProvider: ProviderType
    let llmConfiguration: LLMConfiguration
    let observabilityConfiguration: ObservabilityConfiguration
    let voiceSettings: VoiceSettings
}
