# AutoGPT macOS App - Design Document

## Overview

AutoGPT is a voice-first macOS application that enables users to control their desktop and execute tasks through natural language interactions. The app leverages on-device speech recognition, text-to-speech, accessibility APIs, and configurable LLM backends to provide an intelligent assistant experience.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AutoGPT macOS App                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   UI Layer   │  │ Voice Layer  │  │  LLM Layer   │          │
│  │              │  │              │  │              │          │
│  │ - SwiftUI    │  │ - Whisper    │  │ - Base LLM   │          │
│  │ - Animations │  │ - TTS        │  │ - OpenAI     │          │
│  │ - Sessions   │  │ - Audio I/O  │  │ - Anthropic  │          │
│  └──────────────┘  └──────────────┘  │ - Gemini     │          │
│                                       │ - LiteLLM    │          │
│  ┌──────────────┐  ┌──────────────┐  └──────────────┘          │
│  │System Control│  │ Observability│                             │
│  │              │  │              │                             │
│  │ - Accessibility│ │ - OTLP      │                             │
│  │ - App Control│  │ - Tracing    │                             │
│  │ - Automation │  │ - Phoenix    │                             │
│  └──────────────┘  └──────────────┘                             │
│                                                                   │
│  ┌──────────────────────────────────────────────────┐           │
│  │           Core Services & Data Layer             │           │
│  │  - Session Management                            │           │
│  │  - Configuration                                 │           │
│  │  - Persistence (Core Data / SQLite)              │           │
│  └──────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## Module Design

### 1. Voice Processing Module

#### 1.1 Speech Recognition (Whisper Integration)

**File:** `AutoGPT/VoiceProcessing/SpeechRecognition.swift`

```swift
protocol SpeechRecognitionService {
    func startListening() async throws
    func stopListening() async
    var transcriptionStream: AsyncStream<String> { get }
}

class WhisperSpeechRecognizer: SpeechRecognitionService {
    // On-device Whisper model integration
    // Uses whisper.cpp Swift bindings or MLKit
}
```

#### 1.2 Text-to-Speech (TTS)

**File:** `AutoGPT/VoiceProcessing/TextToSpeech.swift`

```swift
protocol TextToSpeechService {
    func speak(_ text: String, completion: @escaping () -> Void)
    func stop()
    var isSpeaking: Bool { get }
}

class NativeTTSService: TextToSpeechService {
    // Uses AVSpeechSynthesizer or NSSpeechSynthesizer
    // High-quality English voices
}
```

#### 1.3 Audio Management

**File:** `AutoGPT/VoiceProcessing/AudioManager.swift`

```swift
class AudioManager {
    func requestMicrophonePermission() async -> Bool
    func configureAudioSession()
    func handleAudioInterruptions()
}
```

**Directory Structure:**
```
AutoGPT/VoiceProcessing/
├── SpeechRecognition.swift
├── TextToSpeech.swift
├── AudioManager.swift
└── Models/
    └── WhisperModel/ (embedded model files)
```

### 2. LLM Integration Module

#### 2.1 Base LLM Protocol

**File:** `AutoGPT/LLM/BaseLLM.swift`

```swift
// Base protocol for all LLM implementations
protocol LLMProvider {
    var name: String { get }
    var configuration: LLMConfiguration { get set }

    func sendMessage(_ message: Message) async throws -> LLMResponse
    func streamMessage(_ message: Message) -> AsyncThrowingStream<String, Error>
    func cancelRequest()
}

struct LLMConfiguration: Codable {
    var apiKey: String?
    var baseURL: String?
    var model: String
    var temperature: Double
    var maxTokens: Int?
    var systemPrompt: String?
}

struct Message: Codable, Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
}

enum MessageRole: String, Codable {
    case system
    case user
    case assistant
}

struct LLMResponse {
    let content: String
    let metadata: [String: Any]?
    let usage: TokenUsage?
}

struct TokenUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}
```

#### 2.2 Provider Implementations

**File:** `AutoGPT/LLM/Providers/OpenAIProvider.swift`

```swift
import OpenAI // Using official OpenAI Swift SDK

class OpenAIProvider: LLMProvider {
    let name = "OpenAI"
    var configuration: LLMConfiguration
    private let client: OpenAI

    init(configuration: LLMConfiguration) {
        self.configuration = configuration
        self.client = OpenAI(apiToken: configuration.apiKey ?? "")
    }

    func sendMessage(_ message: Message) async throws -> LLMResponse {
        // Implementation using OpenAI SDK
    }

    func streamMessage(_ message: Message) -> AsyncThrowingStream<String, Error> {
        // Streaming implementation
    }
}
```

**File:** `AutoGPT/LLM/Providers/AnthropicProvider.swift`

```swift
import Anthropic // Using Anthropic Swift SDK if available

class AnthropicProvider: LLMProvider {
    let name = "Anthropic"
    var configuration: LLMConfiguration

    // Uses URLSession with Anthropic API if no Swift SDK available
    // Or integrates official SDK when available
}
```

**File:** `AutoGPT/LLM/Providers/GeminiProvider.swift`

```swift
import GoogleGenerativeAI // Using Google's Swift SDK

class GeminiProvider: LLMProvider {
    let name = "Gemini"
    var configuration: LLMConfiguration

    // Implementation using Google's Generative AI SDK
}
```

**File:** `AutoGPT/LLM/Providers/LiteLLMProvider.swift`

```swift
class LiteLLMProvider: LLMProvider {
    let name = "LiteLLM"
    var configuration: LLMConfiguration

    // Uses LiteLLM proxy/server for multi-provider support
    // Most flexible option for configurability
}
```

#### 2.3 LLM Manager

**File:** `AutoGPT/LLM/LLMManager.swift`

```swift
@MainActor
class LLMManager: ObservableObject {
    @Published var currentProvider: LLMProvider
    @Published var isProcessing: Bool = false

    private let observability: ObservabilityService

    init(provider: LLMProvider, observability: ObservabilityService) {
        self.currentProvider = provider
        self.observability = observability
    }

    func switchProvider(_ providerType: ProviderType) {
        // Factory pattern for creating providers
    }

    func sendMessage(_ message: Message, context: ConversationContext) async throws -> LLMResponse {
        // Wraps provider calls with observability
        let span = observability.startSpan(name: "llm.request")
        defer { observability.endSpan(span) }

        return try await currentProvider.sendMessage(message)
    }
}

enum ProviderType: String, CaseIterable, Codable {
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Gemini"
    case litellm = "LiteLLM"
}
```

**Directory Structure:**
```
AutoGPT/LLM/
├── BaseLLM.swift
├── LLMManager.swift
├── Providers/
│   ├── OpenAIProvider.swift
│   ├── AnthropicProvider.swift
│   ├── GeminiProvider.swift
│   └── LiteLLMProvider.swift
└── Models/
    ├── Message.swift
    ├── LLMConfiguration.swift
    └── LLMResponse.swift
```

### 3. System Control Module (Accessibility APIs)

**File:** `AutoGPT/SystemControl/AccessibilityManager.swift`

```swift
import ApplicationServices
import Cocoa

class AccessibilityManager {

    // Request accessibility permissions
    func requestAccessibilityPermissions() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    // Observe running applications
    func observeApplications() -> [NSRunningApplication] {
        return NSWorkspace.shared.runningApplications
    }

    // Get UI elements of an application
    func getUIElements(for app: NSRunningApplication) throws -> [AXUIElement] {
        // Implementation
    }

    // Perform actions on UI elements
    func performAction(_ action: AccessibilityAction) async throws {
        // Implementation
    }
}

enum AccessibilityAction {
    case click(element: AXUIElement)
    case type(text: String, element: AXUIElement)
    case press(key: Key, modifiers: [Modifier])
    case focus(element: AXUIElement)
}
```

**File:** `AutoGPT/SystemControl/AppController.swift`

```swift
class AppController {
    private let accessibility: AccessibilityManager

    func launchApp(_ bundleIdentifier: String) async throws
    func quitApp(_ bundleIdentifier: String) async throws
    func bringAppToFront(_ bundleIdentifier: String) async throws
    func getActiveWindow() -> AXUIElement?
    func getWindowList() -> [WindowInfo]
}

struct WindowInfo {
    let title: String
    let bundleIdentifier: String
    let position: CGPoint
    let size: CGSize
}
```

**File:** `AutoGPT/SystemControl/AutomationEngine.swift`

```swift
@MainActor
class AutomationEngine: ObservableObject {
    private let appController: AppController
    private let accessibility: AccessibilityManager

    func executeTask(_ task: AutomationTask) async throws -> TaskResult {
        // Interprets LLM instructions and executes automation
    }
}

struct AutomationTask: Codable {
    let id: UUID
    let description: String
    let steps: [TaskStep]
}

struct TaskStep: Codable {
    let action: String
    let target: String?
    let parameters: [String: String]
}
```

**Directory Structure:**
```
AutoGPT/SystemControl/
├── AccessibilityManager.swift
├── AppController.swift
├── AutomationEngine.swift
└── Models/
    ├── AccessibilityAction.swift
    └── AutomationTask.swift
```

### 4. Observability & Tracing Module

**File:** `AutoGPT/Observability/ObservabilityService.swift`

```swift
import OpenTelemetryApi
import OpenTelemetrySdk

protocol ObservabilityService {
    func startSpan(name: String, attributes: [String: Any]?) -> Span
    func endSpan(_ span: Span)
    func recordEvent(_ event: String, attributes: [String: Any]?)
    func recordException(_ error: Error, span: Span?)
}

class OTLPObservabilityService: ObservabilityService {
    private let tracer: Tracer
    private let configuration: ObservabilityConfiguration

    init(configuration: ObservabilityConfiguration) {
        self.configuration = configuration
        self.tracer = OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: "AutoGPT",
            instrumentationVersion: "1.0.0"
        )

        configureExporter()
    }

    private func configureExporter() {
        // Configure OTLP exporter to Phoenix/Arize
        let otlpExporter = OtlpHttpTraceExporter(
            endpoint: configuration.endpoint,
            headers: configuration.headers
        )
    }
}

struct ObservabilityConfiguration: Codable {
    let enabled: Bool
    let endpoint: String
    let apiKey: String?
    var headers: [String: String] {
        var headers = ["Content-Type": "application/json"]
        if let apiKey = apiKey {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        return headers
    }
}
```

**File:** `AutoGPT/Observability/LLMTracer.swift`

```swift
class LLMTracer {
    private let observability: ObservabilityService

    func traceLLMRequest(_ message: Message, provider: String) -> Span {
        let span = observability.startSpan(
            name: "llm.chat",
            attributes: [
                "llm.provider": provider,
                "llm.message.role": message.role.rawValue,
                "llm.message.length": message.content.count
            ]
        )
        return span
    }

    func traceLLMResponse(_ response: LLMResponse, span: Span) {
        span.setAttribute(key: "llm.response.length", value: response.content.count)
        if let usage = response.usage {
            span.setAttribute(key: "llm.usage.prompt_tokens", value: usage.promptTokens)
            span.setAttribute(key: "llm.usage.completion_tokens", value: usage.completionTokens)
        }
        observability.endSpan(span)
    }
}
```

**Directory Structure:**
```
AutoGPT/Observability/
├── ObservabilityService.swift
├── LLMTracer.swift
└── Configuration/
    └── ObservabilityConfiguration.swift
```

### 5. Session Management Module

**File:** `AutoGPT/Session/SessionManager.swift`

```swift
@MainActor
class SessionManager: ObservableObject {
    @Published var currentSession: Session?
    @Published var sessions: [Session] = []

    private let persistence: PersistenceService

    func createNewSession() -> Session
    func loadSession(_ id: UUID) async throws
    func saveCurrentSession() async throws
    func deleteSession(_ id: UUID) async throws
    func exportSession(_ id: UUID) async throws -> URL
}

struct Session: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [Message]
    let createdAt: Date
    var updatedAt: Date
    var metadata: SessionMetadata
}

struct SessionMetadata: Codable {
    var totalDuration: TimeInterval
    var messageCount: Int
    var voiceInteractionCount: Int
    var automationTasksExecuted: Int
}
```

**File:** `AutoGPT/Session/PersistenceService.swift`

```swift
protocol PersistenceService {
    func save<T: Codable>(_ object: T, key: String) async throws
    func load<T: Codable>(key: String) async throws -> T
    func delete(key: String) async throws
}

class CoreDataPersistenceService: PersistenceService {
    // Core Data implementation for session persistence
}

// Alternative: SQLite implementation
class SQLitePersistenceService: PersistenceService {
    // SQLite implementation using GRDB.swift
}
```

**Directory Structure:**
```
AutoGPT/Session/
├── SessionManager.swift
├── PersistenceService.swift
├── Models/
│   ├── Session.swift
│   └── SessionMetadata.swift
└── Storage/
    └── AutoGPT.xcdatamodeld (Core Data model)
```

### 6. User Interface Module

**File:** `AutoGPT/Views/MainView.swift`

```swift
import SwiftUI

struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @State private var isListening = false

    var body: some View {
        NavigationSplitView {
            SessionSidebarView(
                sessions: viewModel.sessions,
                currentSession: viewModel.currentSession,
                onSelectSession: viewModel.loadSession,
                onNewSession: viewModel.createNewSession
            )
        } detail: {
            VStack(spacing: 0) {
                // Messages view
                ConversationView(messages: viewModel.currentSession?.messages ?? [])

                // Voice indicator
                VoiceIndicatorView(
                    isListening: isListening,
                    currentTranscription: viewModel.currentTranscription,
                    isSpeaking: viewModel.isSpeaking
                )

                // Input area
                InputControlsView(
                    onVoiceToggle: viewModel.toggleVoiceInput,
                    onSend: viewModel.sendMessage
                )
            }
        }
    }
}
```

**File:** `AutoGPT/Views/ConversationView.swift`

```swift
struct ConversationView: View {
    let messages: [Message]
    @Namespace private var bottomID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    Color.clear.frame(height: 1).id(bottomID)
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    proxy.scrollTo(bottomID)
                }
            }
        }
    }
}
```

**File:** `AutoGPT/Views/MessageBubbleView.swift`

```swift
struct MessageBubbleView: View {
    let message: Message
    @State private var appeared = false

    var body: some View {
        HStack {
            if message.role == .assistant { Spacer() }

            VStack(alignment: message.role == .user ? .leading : .trailing, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(bubbleColor)
                    .foregroundColor(.primary)
                    .cornerRadius(16)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .user { Spacer() }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    var bubbleColor: Color {
        switch message.role {
        case .user: return Color.accentColor.opacity(0.2)
        case .assistant: return Color.gray.opacity(0.1)
        case .system: return Color.yellow.opacity(0.1)
        }
    }
}
```

**File:** `AutoGPT/Views/VoiceIndicatorView.swift`

```swift
struct VoiceIndicatorView: View {
    let isListening: Bool
    let currentTranscription: String
    let isSpeaking: Bool

    var body: some View {
        VStack {
            if isListening || isSpeaking {
                HStack(spacing: 12) {
                    // Animated waveform
                    WaveformView(isActive: isListening || isSpeaking)

                    if !currentTranscription.isEmpty {
                        Text(currentTranscription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }

                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: isListening)
        .animation(.spring(response: 0.3), value: isSpeaking)
    }
}
```

**File:** `AutoGPT/Views/Components/WaveformView.swift`

```swift
struct WaveformView: View {
    let isActive: Bool
    @State private var amplitudes: [CGFloat] = Array(repeating: 0.3, count: 5)

    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 3, height: isActive ? amplitudes[index] * 30 : 3)
                    .animation(.easeInOut(duration: 0.3), value: amplitudes[index])
            }
        }
        .onReceive(timer) { _ in
            if isActive {
                amplitudes = (0..<5).map { _ in CGFloat.random(in: 0.3...1.0) }
            }
        }
    }
}
```

**File:** `AutoGPT/Views/SessionSidebarView.swift`

```swift
struct SessionSidebarView: View {
    let sessions: [Session]
    let currentSession: Session?
    let onSelectSession: (UUID) -> Void
    let onNewSession: () -> Void

    var body: some View {
        List {
            Section {
                Button(action: onNewSession) {
                    Label("New Session", systemImage: "plus.circle.fill")
                }
            }

            Section("Recent Sessions") {
                ForEach(sessions) { session in
                    SessionRowView(session: session)
                        .tag(session.id)
                        .onTapGesture {
                            onSelectSession(session.id)
                        }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

struct SessionRowView: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
                .font(.headline)

            HStack {
                Text(session.updatedAt, style: .date)
                Text("•")
                Text("\(session.messages.count) messages")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

**File:** `AutoGPT/ViewModels/MainViewModel.swift`

```swift
@MainActor
class MainViewModel: ObservableObject {
    @Published var currentSession: Session?
    @Published var sessions: [Session] = []
    @Published var currentTranscription: String = ""
    @Published var isSpeaking: Bool = false
    @Published var isListening: Bool = false

    private let sessionManager: SessionManager
    private let llmManager: LLMManager
    private let speechRecognizer: SpeechRecognitionService
    private let tts: TextToSpeechService
    private let automationEngine: AutomationEngine

    init(
        sessionManager: SessionManager,
        llmManager: LLMManager,
        speechRecognizer: SpeechRecognitionService,
        tts: TextToSpeechService,
        automationEngine: AutomationEngine
    ) {
        self.sessionManager = sessionManager
        self.llmManager = llmManager
        self.speechRecognizer = speechRecognizer
        self.tts = tts
        self.automationEngine = automationEngine

        loadSessions()
    }

    func toggleVoiceInput() async {
        if isListening {
            await speechRecognizer.stopListening()
            isListening = false
        } else {
            try? await speechRecognizer.startListening()
            isListening = true

            for await transcription in speechRecognizer.transcriptionStream {
                currentTranscription = transcription
            }
        }
    }

    func sendMessage(_ content: String) async {
        guard var session = currentSession else { return }

        let userMessage = Message(
            id: UUID(),
            role: .user,
            content: content,
            timestamp: Date()
        )

        session.messages.append(userMessage)
        currentSession = session

        do {
            let response = try await llmManager.sendMessage(
                userMessage,
                context: ConversationContext(session: session)
            )

            let assistantMessage = Message(
                id: UUID(),
                role: .assistant,
                content: response.content,
                timestamp: Date()
            )

            session.messages.append(assistantMessage)
            currentSession = session

            // Speak the response
            tts.speak(response.content) {
                self.isSpeaking = false
            }
            isSpeaking = true

            // Execute any automation tasks if needed
            if let task = parseAutomationTask(from: response.content) {
                try await automationEngine.executeTask(task)
            }

            try await sessionManager.saveCurrentSession()
        } catch {
            // Handle error
        }
    }

    private func parseAutomationTask(from content: String) -> AutomationTask? {
        // Parse LLM response for automation instructions
        return nil
    }

    private func loadSessions() {
        sessions = sessionManager.sessions
    }
}
```

**Directory Structure:**
```
AutoGPT/Views/
├── MainView.swift
├── ConversationView.swift
├── MessageBubbleView.swift
├── VoiceIndicatorView.swift
├── SessionSidebarView.swift
├── InputControlsView.swift
└── Components/
    ├── WaveformView.swift
    └── SettingsView.swift

AutoGPT/ViewModels/
├── MainViewModel.swift
└── SettingsViewModel.swift
```

### 7. Configuration Module

**File:** `AutoGPT/Configuration/AppConfiguration.swift`

```swift
@MainActor
class AppConfiguration: ObservableObject {
    @Published var llmProvider: ProviderType = .anthropic
    @Published var llmConfiguration: LLMConfiguration
    @Published var observabilityConfiguration: ObservabilityConfiguration
    @Published var voiceSettings: VoiceSettings

    private let userDefaults = UserDefaults.standard

    init() {
        // Load from UserDefaults or use defaults
        self.llmConfiguration = Self.loadLLMConfiguration()
        self.observabilityConfiguration = Self.loadObservabilityConfiguration()
        self.voiceSettings = Self.loadVoiceSettings()
    }

    func save() {
        // Save to UserDefaults
    }

    private static func loadLLMConfiguration() -> LLMConfiguration {
        // Load from UserDefaults or return default
        return LLMConfiguration(
            apiKey: nil,
            baseURL: nil,
            model: "claude-3-5-sonnet-20241022",
            temperature: 0.7,
            maxTokens: 4096,
            systemPrompt: """
            You are AutoGPT, an AI assistant running on macOS. You can help users
            by controlling their desktop applications and executing tasks. Always
            confirm potentially destructive actions before executing them.
            """
        )
    }

    private static func loadObservabilityConfiguration() -> ObservabilityConfiguration {
        return ObservabilityConfiguration(
            enabled: true,
            endpoint: "http://localhost:6006/v1/traces",
            apiKey: nil
        )
    }

    private static func loadVoiceSettings() -> VoiceSettings {
        return VoiceSettings(
            voiceName: "com.apple.voice.enhanced.en-US.Samantha",
            speechRate: 0.5,
            autoSpeak: true
        )
    }
}

struct VoiceSettings: Codable {
    var voiceName: String
    var speechRate: Float
    var autoSpeak: Bool
}
```

**Directory Structure:**
```
AutoGPT/Configuration/
├── AppConfiguration.swift
└── ConfigurationKeys.swift
```

## Project Structure

```
AutoGPT/
├── AutoGPTApp.swift                    # Main app entry point
├── ContentView.swift                    # Root view (can be replaced by MainView)
├── Configuration/
│   ├── AppConfiguration.swift
│   └── ConfigurationKeys.swift
├── LLM/
│   ├── BaseLLM.swift
│   ├── LLMManager.swift
│   ├── Providers/
│   │   ├── OpenAIProvider.swift
│   │   ├── AnthropicProvider.swift
│   │   ├── GeminiProvider.swift
│   │   └── LiteLLMProvider.swift
│   └── Models/
│       ├── Message.swift
│       ├── LLMConfiguration.swift
│       └── LLMResponse.swift
├── VoiceProcessing/
│   ├── SpeechRecognition.swift
│   ├── TextToSpeech.swift
│   ├── AudioManager.swift
│   └── Models/
│       └── WhisperModel/
├── SystemControl/
│   ├── AccessibilityManager.swift
│   ├── AppController.swift
│   ├── AutomationEngine.swift
│   └── Models/
│       ├── AccessibilityAction.swift
│       └── AutomationTask.swift
├── Observability/
│   ├── ObservabilityService.swift
│   ├── LLMTracer.swift
│   └── Configuration/
│       └── ObservabilityConfiguration.swift
├── Session/
│   ├── SessionManager.swift
│   ├── PersistenceService.swift
│   ├── Models/
│   │   ├── Session.swift
│   │   └── SessionMetadata.swift
│   └── Storage/
│       └── AutoGPT.xcdatamodeld
├── Views/
│   ├── MainView.swift
│   ├── ConversationView.swift
│   ├── MessageBubbleView.swift
│   ├── VoiceIndicatorView.swift
│   ├── SessionSidebarView.swift
│   ├── InputControlsView.swift
│   └── Components/
│       ├── WaveformView.swift
│       └── SettingsView.swift
├── ViewModels/
│   ├── MainViewModel.swift
│   └── SettingsViewModel.swift
├── DependencyInjection/
│   └── DependencyContainer.swift
├── Extensions/
│   ├── String+Extensions.swift
│   └── View+Extensions.swift
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

## Dependencies

### Swift Package Manager Dependencies

```swift
// Package.swift dependencies
dependencies: [
    // LLM Providers
    .package(url: "https://github.com/MacPaw/OpenAI", from: "0.2.0"),
    .package(url: "https://github.com/google/generative-ai-swift", from: "0.4.0"),

    // Observability
    .package(url: "https://github.com/open-telemetry/opentelemetry-swift", from: "1.0.0"),

    // Persistence
    .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),

    // Utilities
    .package(url: "https://github.com/Alamofire/Alamofire", from: "5.8.0"),
]
```

### Native Frameworks

- **SwiftUI**: Modern UI framework
- **ApplicationServices**: Accessibility APIs
- **AVFoundation**: Audio processing
- **Speech**: Speech recognition (fallback)
- **CoreData**: Persistence
- **Combine**: Reactive programming

### Third-Party Integrations

- **Whisper.cpp**: On-device speech recognition
  - Consider using: https://github.com/ggerganov/whisper.cpp
  - Swift bindings available

- **OpenTelemetry**: OTLP tracing
  - Export to Phoenix/Arize endpoints

## Data Models

### Core Data Schema

```swift
// Session Entity
@Model
class SessionEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var messages: [MessageEntity]
    var metadataJSON: Data // Encoded SessionMetadata
}

// Message Entity
@Model
class MessageEntity {
    @Attribute(.unique) var id: UUID
    var role: String // MessageRole.rawValue
    var content: String
    var timestamp: Date
    @Relationship(inverse: \SessionEntity.messages) var session: SessionEntity?
}
```

## Security & Permissions

### Required Entitlements

**AutoGPT.entitlements:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

### Info.plist Privacy Descriptions

```xml
<key>NSMicrophoneUsageDescription</key>
<string>AutoGPT needs microphone access for voice commands and conversations.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>AutoGPT uses speech recognition to understand your voice commands.</string>

<key>NSAppleEventsUsageDescription</key>
<string>AutoGPT needs to control other applications to execute tasks on your behalf.</string>
```

### Accessibility Permissions

Users must grant accessibility permissions in **System Preferences > Security & Privacy > Privacy > Accessibility** for AutoGPT to control other applications.

## User Flow

### 1. First Launch

1. User launches AutoGPT
2. App requests microphone permission
3. App prompts for accessibility permissions
4. User configures LLM provider and API key in settings
5. (Optional) User configures observability endpoint

### 2. Voice Interaction Flow

```
┌─────────────────────────────────────────────────────────────┐
│ User clicks microphone button or uses hotkey                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ SpeechRecognizer starts listening (Whisper)                  │
│ Shows animated waveform and live transcription              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ User finishes speaking, transcription complete              │
│ Message added to conversation view                          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ LLMManager sends message to configured provider             │
│ ObservabilityService traces the request                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ LLM response received and displayed                         │
│ TTS speaks the response aloud                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ If response contains automation task:                       │
│   - AutomationEngine parses instructions                    │
│   - Executes via AccessibilityManager                       │
│   - Shows progress/result to user                           │
└─────────────────────────────────────────────────────────────┘
```

### 3. Session Management

- Sessions are auto-saved after each message
- User can create new sessions from sidebar
- User can load previous sessions
- Sessions show metadata (message count, duration, etc.)
- Export sessions to JSON for backup

## UI/UX Design Principles

### Visual Design

1. **Clean & Minimal**: Focus on conversation, minimal chrome
2. **Smooth Animations**: Spring-based animations for all transitions
3. **Voice-First Indicators**: Clear visual feedback for voice states
4. **Glassmorphism**: Use `.ultraThinMaterial` for panels and overlays
5. **Color Scheme**: Adaptive (supports Light/Dark mode)

### Animations

- **Message appearance**: Slide up + fade in with spring animation
- **Voice indicator**: Smooth expand/collapse with waveform animation
- **Session switching**: Crossfade transition
- **Typing indicator**: Animated dots while LLM is thinking

### Accessibility

- Full VoiceOver support
- Keyboard shortcuts for all major actions
- High contrast mode support
- Configurable text sizes

## Error Handling

### Error Types

```swift
enum AutoGPTError: LocalizedError {
    case permissionDenied(PermissionType)
    case llmError(LLMError)
    case automationError(String)
    case speechRecognitionFailed
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let type):
            return "Permission denied: \(type.description)"
        case .llmError(let error):
            return "LLM Error: \(error.localizedDescription)"
        case .automationError(let message):
            return "Automation failed: \(message)"
        case .speechRecognitionFailed:
            return "Speech recognition failed"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

enum PermissionType {
    case microphone
    case accessibility
    case automation

    var description: String {
        switch self {
        case .microphone: return "Microphone access"
        case .accessibility: return "Accessibility permissions"
        case .automation: return "Automation permissions"
        }
    }
}
```

### Error Presentation

- Non-blocking toast notifications for minor errors
- Modal alerts for critical errors (permission denials)
- Inline error messages in conversation view
- Retry mechanisms with exponential backoff

## Performance Considerations

### Optimization Strategies

1. **Lazy Loading**: Messages loaded lazily in conversation view
2. **Debouncing**: Voice transcription updates debounced to reduce UI updates
3. **Background Processing**: LLM requests on background queue
4. **Caching**: Cache frequently used accessibility elements
5. **Memory Management**: Limit session history in memory, paginate old messages

### Resource Management

- Automatic cleanup of old sessions (configurable retention)
- Compress old session data
- Limit concurrent API requests
- Release audio resources when not in use

## Testing Strategy

### Unit Tests

- LLM provider implementations
- Message parsing and formatting
- Session management logic
- Configuration management

### Integration Tests

- LLM provider switching
- Session persistence
- Voice pipeline (mocked)
- Automation engine (mocked accessibility)

### UI Tests

- Session creation and loading
- Message sending and receiving
- Settings configuration
- Voice indicator animations

## Deployment

### Build Configuration

**Debug:**
- Local observability endpoint
- Verbose logging
- Mock accessibility for simulator

**Release:**
- Production observability endpoint
- Minimal logging
- Code signing and notarization required

### Distribution

- Mac App Store (requires App Sandbox compliance)
- Direct distribution (DMG with notarization)

## Future Enhancements

### Phase 2 Features

1. **Multi-modal Input**: Image/screenshot analysis
2. **Shortcuts Integration**: Siri shortcuts for common tasks
3. **Plugin System**: Community-built automation plugins
4. **Team Collaboration**: Shared session templates
5. **Advanced Automation**: Visual workflow builder
6. **Context Awareness**: Learn user patterns and preferences
7. **Multi-language Support**: Beyond English
8. **Custom Wake Word**: "Hey AutoGPT" activation

### Phase 3 Features

1. **iOS Companion App**: Control Mac from iPhone/iPad
2. **Cloud Sync**: Sync sessions across devices
3. **Advanced Analytics**: Usage insights and productivity metrics
4. **Workspace Integration**: Slack, Email, Calendar integration
5. **Vision Pro Support**: Spatial computing interface

## Configuration Examples

### LiteLLM Configuration

```yaml
# litellm_config.yaml
model_list:
  - model_name: gpt-4
    litellm_params:
      model: openai/gpt-4
      api_key: ${OPENAI_API_KEY}

  - model_name: claude-3-sonnet
    litellm_params:
      model: anthropic/claude-3-sonnet-20240229
      api_key: ${ANTHROPIC_API_KEY}

  - model_name: gemini-pro
    litellm_params:
      model: gemini/gemini-pro
      api_key: ${GOOGLE_API_KEY}
```

### Phoenix Observability Setup

```swift
// Configure Phoenix/Arize endpoint
let observabilityConfig = ObservabilityConfiguration(
    enabled: true,
    endpoint: "https://your-phoenix-instance.com/v1/traces",
    apiKey: "your-api-key"
)
```

## Conclusion

This design provides a modular, extensible architecture for AutoGPT that:

- ✅ Supports multiple LLM providers with easy switching
- ✅ Integrates on-device speech recognition and TTS
- ✅ Leverages macOS accessibility APIs for system control
- ✅ Implements OTLP-based observability for LLM tracing
- ✅ Provides a modern, animated UI with session management
- ✅ Follows Swift and SwiftUI best practices
- ✅ Designed for extensibility and future enhancements

The modular architecture allows for independent development and testing of each component while maintaining clean separation of concerns. The use of protocols and dependency injection makes the system highly testable and maintainable.
