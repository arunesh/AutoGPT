//
//  ConversationView.swift
//  AutoGPT
//
//  Conversation messages view with animations
//

import SwiftUI

struct ConversationView: View {
    let messages: [Message]
    @Namespace private var bottomID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
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
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }
}
