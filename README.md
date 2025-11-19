# AutoGPT - AI-Powered macOS Assistant

AutoGPT is a voice-first macOS application that enables users to control their desktop and execute tasks through natural language interactions powered by LLMs.

## Features

- 🎤 **Voice Interaction**: On-device speech recognition and text-to-speech
- 🤖 **Multi-LLM Support**: OpenAI, Anthropic Claude, Google Gemini, and LiteLLM
- 🖥️ **Desktop Automation**: Control macOS applications using Accessibility APIs
- 📊 **Observability**: OTLP-based tracing for LLM interactions (Phoenix/Arize compatible)
- 💾 **Session Management**: Save and restore conversation sessions
- ✨ **Modern UI**: Clean SwiftUI interface with smooth animations

## Architecture

The application follows a modular, protocol-oriented design:

```
AutoGPT/
├── LLM/                    # LLM integration layer
│   ├── BaseLLM.swift       # Protocol definitions
│   ├── LLMManager.swift    # Provider management
│   ├── Providers/          # Provider implementations
│   └── Models/             # Data models
├── VoiceProcessing/        # Speech recognition & TTS
├── SystemControl/          # Accessibility & automation
├── Observability/          # Tracing & monitoring
├── Session/                # Session management
├── Views/                  # SwiftUI views
├── ViewModels/             # View models
├── Configuration/          # App configuration
└── DependencyInjection/    # DI container
```

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/AutoGPT.git
cd AutoGPT
```

### 2. Configure LLM Provider

On first launch, you'll need to configure your LLM provider:

1. Open Settings in the app
2. Select your preferred provider (OpenAI, Anthropic, Gemini, or LiteLLM)
3. Enter your API key
4. Configure model settings (temperature, max tokens, etc.)

### 3. Grant Permissions

AutoGPT requires the following permissions:

#### Microphone Access
- Required for voice input
- The app will prompt you on first use

#### Accessibility Permissions
- Required for desktop automation
- Go to **System Preferences > Security & Privacy > Privacy > Accessibility**
- Add AutoGPT to the list of allowed applications

#### Speech Recognition
- Required for on-device speech recognition
- The app will prompt you on first use

## Usage

### Voice Interaction

1. Click the microphone button or press the hotkey
2. Speak your command or question
3. AutoGPT will transcribe, process, and respond

### Text Input

Type your message in the input field and press Enter or click the send button.

### Session Management

- Create a new session: Cmd+N
- Switch sessions: Click on a session in the sidebar
- Delete sessions: Right-click on a session and select "Delete"

### Desktop Automation

AutoGPT can perform desktop automation tasks like:

```
"Open Safari and navigate to example.com"
"Create a new note in Notes app"
"Switch to Mail and compose a new email"
```

## Configuration

### LLM Providers

#### OpenAI
```swift
// Configuration example
LLMConfiguration(
    apiKey: "your-api-key",
    model: "gpt-4",
    temperature: 0.7,
    maxTokens: 4096
)
```

#### Anthropic
```swift
LLMConfiguration(
    apiKey: "your-api-key",
    model: "claude-3-5-sonnet-20241022",
    temperature: 0.7,
    maxTokens: 4096
)
```

#### Google Gemini
```swift
LLMConfiguration(
    apiKey: "your-api-key",
    model: "gemini-pro",
    temperature: 0.7,
    maxTokens: 4096
)
```

#### LiteLLM (Multi-provider proxy)
```swift
LLMConfiguration(
    baseURL: "http://localhost:8000",
    model: "gpt-4",
    temperature: 0.7
)
```

### Observability

To enable tracing with Phoenix/Arize:

```swift
ObservabilityConfiguration(
    enabled: true,
    endpoint: "http://localhost:6006/v1/traces",
    apiKey: "your-api-key" // Optional
)
```

## Development

### Project Structure

- **LLM Module**: Handles all LLM provider integrations
- **Voice Processing**: Speech recognition and TTS
- **System Control**: Accessibility APIs and automation
- **Observability**: OTLP tracing for monitoring
- **Session Management**: Conversation persistence
- **UI Layer**: SwiftUI views and view models

### Adding a New LLM Provider

1. Create a new file in `AutoGPT/LLM/Providers/`
2. Implement the `LLMProvider` protocol
3. Add the provider to `LLMManager.createProvider()`
4. Update `ProviderType` enum

Example:

```swift
class CustomProvider: LLMProvider {
    let name = "Custom"
    var configuration: LLMConfiguration

    func sendMessage(_ message: Message, context: [Message]) async throws -> LLMResponse {
        // Implementation
    }
}
```

### Testing

```bash
# Run tests
xcodebuild test -scheme AutoGPT

# Or use Xcode
Cmd+U
```

## Security & Privacy

- API keys are stored securely in the app's sandboxed container
- Voice data is processed on-device when possible
- Network requests are only made to configured LLM endpoints
- Accessibility permissions are used only for user-requested automation

## Troubleshooting

### Microphone Not Working

1. Check System Preferences > Security & Privacy > Privacy > Microphone
2. Ensure AutoGPT is in the allowed list
3. Restart the application

### Accessibility Permissions Not Working

1. Open System Preferences > Security & Privacy > Privacy > Accessibility
2. Add AutoGPT to the list
3. Restart the application

### LLM API Errors

- Verify your API key is correct
- Check network connectivity
- Ensure you're not hitting rate limits
- Check the error message in the UI

## Future Enhancements

- [ ] Whisper.cpp integration for fully on-device speech recognition
- [ ] Multi-language support
- [ ] Plugin system for custom automations
- [ ] iOS companion app
- [ ] Cloud sync for sessions
- [ ] Advanced workflow builder

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

Copyright © 2025. All rights reserved.

## Acknowledgments

- OpenAI for GPT models
- Anthropic for Claude
- Google for Gemini
- OpenTelemetry for observability standards
- Phoenix/Arize for trace collection

## Contact

For questions or support, please open an issue on GitHub.
