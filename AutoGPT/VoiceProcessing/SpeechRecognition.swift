//
//  SpeechRecognition.swift
//  AutoGPT
//
//  Speech recognition service using macOS Speech framework
//  Note: For production, integrate Whisper.cpp for on-device recognition
//

import Foundation
import Speech
import AVFoundation

protocol SpeechRecognitionService {
    func startListening() async throws
    func stopListening() async
    var transcriptionStream: AsyncStream<String> { get }
    var isListening: Bool { get }
}

@MainActor
class NativeSpeechRecognizer: NSObject, SpeechRecognitionService, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var transcriptionContinuation: AsyncStream<String>.Continuation?

    private(set) var isListening = false

    var transcriptionStream: AsyncStream<String> {
        AsyncStream { continuation in
            self.transcriptionContinuation = continuation
        }
    }

    override init() {
        super.init()
        speechRecognizer?.delegate = self
    }

    func startListening() async throws {
        // Request authorization
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus != .authorized {
            let status = await requestAuthorization()
            guard status == .authorized else {
                throw SpeechRecognitionError.notAuthorized
            }
        }

        // Check if speech recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerNotAvailable
        }

        // Cancel any ongoing recognition
        if recognitionTask != nil {
            await stopListening()
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.failedToCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Set to true for fully on-device

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.transcriptionContinuation?.yield(transcription)
                }
            }

            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    await self.stopListening()
                }
            }
        }
    }

    func stopListening() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
    }

    private func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - SFSpeechRecognizerDelegate

    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        // Handle availability changes
    }
}

// MARK: - Whisper-based Speech Recognizer (Placeholder)

/// This is a placeholder for Whisper.cpp integration
/// In production, integrate whisper.cpp Swift bindings for fully on-device recognition
class WhisperSpeechRecognizer: SpeechRecognitionService {
    private(set) var isListening = false
    private var transcriptionContinuation: AsyncStream<String>.Continuation?

    var transcriptionStream: AsyncStream<String> {
        AsyncStream { continuation in
            self.transcriptionContinuation = continuation
        }
    }

    func startListening() async throws {
        // TODO: Integrate whisper.cpp
        // 1. Initialize whisper model
        // 2. Start audio capture
        // 3. Process audio chunks through whisper
        // 4. Emit transcriptions
        throw SpeechRecognitionError.notImplemented
    }

    func stopListening() async {
        // TODO: Stop whisper processing
        isListening = false
    }
}

// MARK: - Errors

enum SpeechRecognitionError: LocalizedError {
    case notAuthorized
    case recognizerNotAvailable
    case failedToCreateRequest
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .recognizerNotAvailable:
            return "Speech recognizer is not available"
        case .failedToCreateRequest:
            return "Failed to create recognition request"
        case .notImplemented:
            return "Whisper integration not yet implemented"
        }
    }
}
