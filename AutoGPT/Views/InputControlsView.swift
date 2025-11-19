//
//  InputControlsView.swift
//  AutoGPT
//
//  Input controls for text and voice
//

import SwiftUI

struct InputControlsView: View {
    let isListening: Bool
    let isSpeaking: Bool
    let isProcessing: Bool
    let onVoiceToggle: () -> Void
    let onSend: (String) -> Void
    let onStopSpeaking: () -> Void

    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Voice button
            Button(action: onVoiceToggle) {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.system(size: 20))
                    .foregroundColor(isListening ? .red : .accentColor)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing || isSpeaking)

            // Text input
            TextField("Type a message...", text: $inputText)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .focused($isInputFocused)
                .disabled(isListening || isProcessing)
                .onSubmit {
                    sendMessage()
                }

            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(inputText.isEmpty ? .secondary : .accentColor)
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty || isListening || isProcessing)

            // Stop speaking button
            if isSpeaking {
                Button(action: onStopSpeaking) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            // Processing indicator
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: isProcessing)
        .animation(.spring(response: 0.3), value: isSpeaking)
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        onSend(inputText)
        inputText = ""
    }
}
