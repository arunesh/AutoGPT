//
//  AudioManager.swift
//  AutoGPT
//
//  Audio session and permissions management
//

import Foundation
import AVFoundation

class AudioManager {
    static let shared = AudioManager()

    private init() {}

    /// Request microphone permission
    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Configure audio session for recording
    func configureAudioSessionForRecording() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Configure audio session for playback
    func configureAudioSessionForPlayback() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Deactivate audio session
    func deactivateAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Check if microphone permission is granted
    var isMicrophoneAuthorized: Bool {
        AVAudioSession.sharedInstance().recordPermission == .granted
    }
}
