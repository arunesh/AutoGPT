//
//  SessionSidebarView.swift
//  AutoGPT
//
//  Session list sidebar
//

import SwiftUI

struct SessionSidebarView: View {
    let sessions: [Session]
    let currentSession: Session?
    let onSelectSession: (UUID) -> Void
    let onNewSession: () -> Void
    let onDeleteSession: (UUID) -> Void

    var body: some View {
        List {
            Section {
                Button(action: onNewSession) {
                    Label("New Session", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }

            Section("Recent Sessions") {
                ForEach(sessions) { session in
                    SessionRowView(
                        session: session,
                        isSelected: session.id == currentSession?.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectSession(session.id)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            onDeleteSession(session.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("AutoGPT")
    }
}

struct SessionRowView: View {
    let session: Session
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
                .font(.headline)
                .lineLimit(1)
                .foregroundColor(isSelected ? .accentColor : .primary)

            HStack {
                Text(session.updatedAt, style: .relative)
                Text("•")
                Text("\(session.messages.count) messages")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
