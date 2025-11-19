//
//  MessageBubbleView.swift
//  AutoGPT
//
//  Message bubble view with animations
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.role == .user ? .leading : .trailing, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(bubbleColor)
                    .foregroundColor(.primary)
                    .cornerRadius(16)
                    .textSelection(.enabled)

                HStack(spacing: 4) {
                    if message.role != .user {
                        Image(systemName: roleIcon)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if message.role == .user {
                Spacer(minLength: 50)
            }
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
        case .user:
            return Color.accentColor.opacity(0.2)
        case .assistant:
            return Color(nsColor: .controlBackgroundColor)
        case .system:
            return Color.yellow.opacity(0.1)
        }
    }

    var roleIcon: String {
        switch message.role {
        case .user:
            return "person.circle"
        case .assistant:
            return "cpu"
        case .system:
            return "info.circle"
        }
    }
}
