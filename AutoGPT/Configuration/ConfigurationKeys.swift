//
//  ConfigurationKeys.swift
//  AutoGPT
//
//  Configuration constants and keys
//

import Foundation

enum ConfigurationKeys {
    static let appConfiguration = "app_configuration"
    static let currentSessionId = "current_session_id"
    static let hasShownOnboarding = "has_shown_onboarding"
    static let hasRequestedMicrophonePermission = "has_requested_microphone_permission"
    static let hasRequestedAccessibilityPermission = "has_requested_accessibility_permission"
}

enum AppConstants {
    static let appName = "AutoGPT"
    static let appVersion = "1.0.0"
    static let minOSVersion = "13.0"

    // UI Constants
    static let animationDuration = 0.3
    static let springResponse = 0.4
    static let springDampingFraction = 0.7

    // Voice Constants
    static let maxRecordingDuration: TimeInterval = 300 // 5 minutes
    static let silenceThreshold: TimeInterval = 2.0 // 2 seconds of silence

    // Session Constants
    static let maxSessionsToKeep = 100
    static let maxMessagesPerSession = 1000
}
