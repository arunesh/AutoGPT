//
//  MainView.swift
//  AutoGPT
//
//  Main view of the application
//

import SwiftUI

struct MainView: View {
    @StateObject var viewModel: MainViewModel

    var body: some View {
        NavigationSplitView {
            SessionSidebarView(
                sessions: viewModel.sessions,
                currentSession: viewModel.currentSession,
                onSelectSession: { id in viewModel.loadSession(id) },
                onNewSession: { viewModel.createNewSession() },
                onDeleteSession: { id in viewModel.deleteSession(id) }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            VStack(spacing: 0) {
                // Messages view
                ConversationView(messages: viewModel.currentSession?.messages ?? [])

                // Voice indicator
                if viewModel.isListening || viewModel.isSpeaking {
                    VoiceIndicatorView(
                        isListening: viewModel.isListening,
                        currentTranscription: viewModel.currentTranscription,
                        isSpeaking: viewModel.isSpeaking
                    )
                    .padding()
                }

                // Input area
                InputControlsView(
                    isListening: viewModel.isListening,
                    isSpeaking: viewModel.isSpeaking,
                    isProcessing: viewModel.isProcessingMessage,
                    onVoiceToggle: {
                        Task {
                            await viewModel.toggleVoiceInput()
                        }
                    },
                    onSend: { text in
                        Task {
                            await viewModel.sendMessage(text)
                        }
                    },
                    onStopSpeaking: {
                        viewModel.stopSpeaking()
                    }
                )
                .padding()
            }
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}
