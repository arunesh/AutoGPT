//
//  VoiceIndicatorView.swift
//  AutoGPT
//
//  Voice indicator with waveform animation
//

import SwiftUI

struct VoiceIndicatorView: View {
    let isListening: Bool
    let currentTranscription: String
    let isSpeaking: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Animated waveform
            WaveformView(isActive: isListening || isSpeaking)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                if !currentTranscription.isEmpty {
                    Text(currentTranscription)
                        .font(.body)
                        .foregroundColor(.primary)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: isListening)
        .animation(.spring(response: 0.3), value: isSpeaking)
    }

    var statusText: String {
        if isListening {
            return "Listening..."
        } else if isSpeaking {
            return "Speaking..."
        } else {
            return ""
        }
    }
}
