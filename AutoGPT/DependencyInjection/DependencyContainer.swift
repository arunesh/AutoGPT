//
//  DependencyContainer.swift
//  AutoGPT
//
//  Dependency injection container for the application
//

import Foundation

@MainActor
class DependencyContainer {
    // MARK: - Shared Instance

    static let shared = DependencyContainer()

    // MARK: - Configuration

    let appConfiguration: AppConfiguration

    // MARK: - Services

    let persistenceService: PersistenceService
    let observabilityService: ObservabilityService
    let audioManager: AudioManager

    // MARK: - Core Modules

    let sessionManager: SessionManager
    let llmManager: LLMManager

    // MARK: - Voice Processing

    let speechRecognizer: SpeechRecognitionService
    let tts: TextToSpeechService

    // MARK: - System Control

    let accessibilityManager: AccessibilityManager
    let appController: AppController
    let automationEngine: AutomationEngine

    // MARK: - ViewModels

    private(set) var mainViewModel: MainViewModel!

    // MARK: - Initialization

    private init() {
        // Initialize configuration
        self.appConfiguration = AppConfiguration()

        // Initialize audio manager
        self.audioManager = AudioManager.shared

        // Initialize persistence
        self.persistenceService = (try? FilePersistenceService()) ?? UserDefaultsPersistenceService()

        // Initialize observability
        if appConfiguration.observabilityConfiguration.enabled {
            self.observabilityService = SimpleOTLPObservabilityService(
                configuration: appConfiguration.observabilityConfiguration
            )
        } else {
            self.observabilityService = NoOpObservabilityService()
        }

        // Initialize session manager
        self.sessionManager = SessionManager(persistence: persistenceService)

        // Initialize LLM provider
        let provider = LLMManager.createProvider(
            type: appConfiguration.llmProvider,
            configuration: appConfiguration.llmConfiguration
        )

        // Initialize LLM manager
        self.llmManager = LLMManager(
            provider: provider,
            observability: observabilityService
        )

        // Initialize voice processing
        self.speechRecognizer = NativeSpeechRecognizer()
        self.tts = NativeTTSService()

        // Apply voice settings
        if let ttsService = tts as? NativeTTSService {
            ttsService.voiceName = appConfiguration.voiceSettings.voiceName
            ttsService.speechRate = appConfiguration.voiceSettings.speechRate
        }

        // Initialize system control
        self.accessibilityManager = AccessibilityManager()
        self.appController = AppController(accessibility: accessibilityManager)
        self.automationEngine = AutomationEngine(
            appController: appController,
            accessibility: accessibilityManager
        )

        // Initialize main view model
        self.mainViewModel = MainViewModel(
            sessionManager: sessionManager,
            llmManager: llmManager,
            speechRecognizer: speechRecognizer,
            tts: tts,
            automationEngine: automationEngine,
            configuration: appConfiguration
        )
    }

    // MARK: - Configuration Updates

    func updateLLMProvider(_ providerType: ProviderType, configuration: LLMConfiguration) {
        llmManager.switchProvider(providerType, configuration: configuration)
        appConfiguration.llmProvider = providerType
        appConfiguration.llmConfiguration = configuration
        appConfiguration.save()
    }

    func updateVoiceSettings(_ settings: VoiceSettings) {
        if let ttsService = tts as? NativeTTSService {
            ttsService.voiceName = settings.voiceName
            ttsService.speechRate = settings.speechRate
        }

        appConfiguration.voiceSettings = settings
        appConfiguration.save()
    }

    func updateObservabilityConfiguration(_ configuration: ObservabilityConfiguration) {
        appConfiguration.observabilityConfiguration = configuration
        appConfiguration.save()
    }

    // MARK: - Permissions

    func checkAndRequestPermissions() async -> (microphone: Bool, accessibility: Bool) {
        // Check microphone permission
        let microphoneGranted = await audioManager.requestMicrophonePermission()

        // Check accessibility permission
        let accessibilityGranted = accessibilityManager.isAccessibilityEnabled

        if !accessibilityGranted {
            _ = accessibilityManager.requestAccessibilityPermissions()
        }

        return (microphoneGranted, accessibilityGranted)
    }
}
