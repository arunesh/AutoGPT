//
//  MainViewModel.swift
//  AutoGPT
//
//  Main view model for the application
//

import Foundation
import Combine

@MainActor
class MainViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentSession: Session?
    @Published var sessions: [Session] = []
    @Published var currentTranscription: String = ""
    @Published var isSpeaking: Bool = false
    @Published var isListening: Bool = false
    @Published var isProcessingMessage: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let sessionManager: SessionManager
    private let llmManager: LLMManager
    private let speechRecognizer: SpeechRecognitionService
    private let tts: TextToSpeechService
    private let automationEngine: AutomationEngine
    private let configuration: AppConfiguration

    private var cancellables = Set<AnyCancellable>()
    private var transcriptionTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        sessionManager: SessionManager,
        llmManager: LLMManager,
        speechRecognizer: SpeechRecognitionService,
        tts: TextToSpeechService,
        automationEngine: AutomationEngine,
        configuration: AppConfiguration
    ) {
        self.sessionManager = sessionManager
        self.llmManager = llmManager
        self.speechRecognizer = speechRecognizer
        self.tts = tts
        self.automationEngine = automationEngine
        self.configuration = configuration

        setupBindings()
        loadSessions()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe session manager changes
        sessionManager.$currentSession
            .assign(to: &$currentSession)

        sessionManager.$sessions
            .assign(to: &$sessions)

        // Observe LLM processing state
        llmManager.$isProcessing
            .assign(to: &$isProcessingMessage)
    }

    private func loadSessions() {
        sessions = sessionManager.sessions
        currentSession = sessionManager.currentSession

        // Create new session if none exists
        if currentSession == nil {
            createNewSession()
        }
    }

    // MARK: - Session Management

    func createNewSession() {
        let session = sessionManager.createNewSession()
        currentSession = session
    }

    func loadSession(_ id: UUID) {
        Task {
            do {
                try await sessionManager.loadSession(id)
            } catch {
                errorMessage = "Failed to load session: \(error.localizedDescription)"
            }
        }
    }

    func deleteSession(_ id: UUID) {
        Task {
            do {
                try await sessionManager.deleteSession(id)
            } catch {
                errorMessage = "Failed to delete session: \(error.localizedDescription)"
            }
        }
    }

    func updateSessionTitle(_ title: String) {
        Task {
            await sessionManager.updateSessionTitle(title)
        }
    }

    // MARK: - Voice Interaction

    func toggleVoiceInput() async {
        if isListening {
            await stopListening()
        } else {
            await startListening()
        }
    }

    private func startListening() async {
        do {
            try await speechRecognizer.startListening()
            isListening = true

            // Monitor transcription stream
            transcriptionTask = Task {
                for await transcription in speechRecognizer.transcriptionStream {
                    currentTranscription = transcription
                }

                // When stream ends, send the final transcription
                if !currentTranscription.isEmpty {
                    await sendMessage(currentTranscription)
                    currentTranscription = ""
                }
            }
        } catch {
            errorMessage = "Failed to start listening: \(error.localizedDescription)"
            isListening = false
        }
    }

    private func stopListening() async {
        await speechRecognizer.stopListening()
        isListening = false
        transcriptionTask?.cancel()
        transcriptionTask = nil
    }

    // MARK: - Message Handling

    func sendMessage(_ content: String) async {
        guard !content.isEmpty else { return }
        guard var session = currentSession else {
            createNewSession()
            guard let newSession = currentSession else { return }
            session = newSession
        }

        // Create user message
        let userMessage = Message(
            role: .user,
            content: content
        )

        // Add to session
        await sessionManager.addMessage(userMessage)

        // Send to LLM
        do {
            let context = session.messages.filter { $0.role != .system }
            let response = try await llmManager.sendMessage(userMessage, context: context)

            // Create assistant message
            let assistantMessage = Message(
                role: .assistant,
                content: response.content
            )

            // Add to session
            await sessionManager.addMessage(assistantMessage)

            // Speak the response if auto-speak is enabled
            if configuration.voiceSettings.autoSpeak {
                speakText(response.content)
            }

            // Check for automation tasks
            if let task = parseAutomationTask(from: response.content) {
                await executeAutomationTask(task)
            }

            // Auto-generate title for new sessions
            if session.messages.count == 2 && session.title.hasPrefix("New Session") {
                await generateSessionTitle()
            }

        } catch {
            errorMessage = "Failed to send message: \(error.localizedDescription)"
        }
    }

    func sendMessageStream(_ content: String) async {
        guard !content.isEmpty else { return }
        guard var session = currentSession else {
            createNewSession()
            guard let newSession = currentSession else { return }
            session = newSession
        }

        // Create user message
        let userMessage = Message(
            role: .user,
            content: content
        )

        // Add to session
        await sessionManager.addMessage(userMessage)

        // Stream from LLM
        var accumulatedContent = ""
        let context = session.messages.filter { $0.role != .system }

        do {
            for try await chunk in llmManager.streamMessage(userMessage, context: context) {
                accumulatedContent += chunk
                // You could emit this to update UI in real-time
            }

            // Create assistant message with full content
            let assistantMessage = Message(
                role: .assistant,
                content: accumulatedContent
            )

            // Add to session
            await sessionManager.addMessage(assistantMessage)

            // Speak if enabled
            if configuration.voiceSettings.autoSpeak {
                speakText(accumulatedContent)
            }

        } catch {
            errorMessage = "Failed to stream message: \(error.localizedDescription)"
        }
    }

    // MARK: - Text-to-Speech

    func speakText(_ text: String) {
        isSpeaking = true
        tts.speak(text) { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = false
            }
        }
    }

    func stopSpeaking() {
        tts.stop()
        isSpeaking = false
    }

    // MARK: - Automation

    private func executeAutomationTask(_ task: AutomationTask) async {
        do {
            let result = try await automationEngine.executeTask(task)

            // Add result as system message
            let systemMessage = Message(
                role: .system,
                content: "Automation result: \(result.message)"
            )

            await sessionManager.addMessage(systemMessage)

        } catch {
            errorMessage = "Automation failed: \(error.localizedDescription)"
        }
    }

    private func parseAutomationTask(from content: String) -> AutomationTask? {
        // Try to parse structured automation commands from LLM response
        // This is a simple implementation - in production, the LLM would
        // return JSON with structured task definitions

        return automationEngine.parseTaskFromText(content)
    }

    // MARK: - Utilities

    private func generateSessionTitle() async {
        guard let session = currentSession,
              let firstUserMessage = session.messages.first(where: { $0.role == .user }) else {
            return
        }

        // Use first user message as title (truncated)
        let title = String(firstUserMessage.content.prefix(50))
        await updateSessionTitle(title)
    }

    func clearError() {
        errorMessage = nil
    }
}
