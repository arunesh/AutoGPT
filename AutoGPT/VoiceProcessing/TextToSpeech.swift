//
//  TextToSpeech.swift
//  AutoGPT
//
//  Text-to-speech service using macOS native TTS
//

import Foundation
import AVFoundation

protocol TextToSpeechService {
    func speak(_ text: String, completion: @escaping () -> Void)
    func stop()
    var isSpeaking: Bool { get }
}

@MainActor
class NativeTTSService: NSObject, TextToSpeechService, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var completionHandler: (() -> Void)?

    var voiceName: String = "com.apple.voice.enhanced.en-US.Samantha"
    var speechRate: Float = 0.5

    private(set) var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, completion: @escaping () -> Void) {
        self.completionHandler = completion

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(identifier: voiceName)
        utterance.rate = speechRate

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        completionHandler?()
        completionHandler = nil
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.completionHandler?()
            self.completionHandler = nil
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.completionHandler?()
            self.completionHandler = nil
        }
    }
}

// MARK: - Voice Settings

struct VoiceSettings: Codable {
    var voiceName: String
    var speechRate: Float
    var autoSpeak: Bool

    init(
        voiceName: String = "com.apple.voice.enhanced.en-US.Samantha",
        speechRate: Float = 0.5,
        autoSpeak: Bool = true
    ) {
        self.voiceName = voiceName
        self.speechRate = speechRate
        self.autoSpeak = autoSpeak
    }
}
