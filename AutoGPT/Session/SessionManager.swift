//
//  SessionManager.swift
//  AutoGPT
//
//  Manager for session lifecycle and persistence
//

import Foundation

@MainActor
class SessionManager: ObservableObject {
    @Published var currentSession: Session?
    @Published var sessions: [Session] = []

    private let persistence: PersistenceService
    private let sessionPrefix = "session_"

    init(persistence: PersistenceService) {
        self.persistence = persistence
        Task {
            await loadAllSessions()
        }
    }

    /// Create a new session
    func createNewSession() -> Session {
        let session = Session(
            title: "New Session \(sessions.count + 1)"
        )

        sessions.insert(session, at: 0)
        currentSession = session

        Task {
            await saveSession(session)
        }

        return session
    }

    /// Load a session by ID
    func loadSession(_ id: UUID) async throws {
        if let session = sessions.first(where: { $0.id == id }) {
            currentSession = session
        } else {
            // Try loading from persistence
            let session: Session = try await persistence.load(key: sessionKey(for: id))
            currentSession = session

            if !sessions.contains(where: { $0.id == id }) {
                sessions.insert(session, at: 0)
            }
        }
    }

    /// Save current session
    func saveCurrentSession() async throws {
        guard let session = currentSession else { return }
        try await saveSession(session)
    }

    /// Save a specific session
    func saveSession(_ session: Session) async {
        do {
            try await persistence.save(session, key: sessionKey(for: session.id))

            // Update in memory array
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
            }
        } catch {
            print("Failed to save session: \(error.localizedDescription)")
        }
    }

    /// Delete a session
    func deleteSession(_ id: UUID) async throws {
        try await persistence.delete(key: sessionKey(for: id))

        sessions.removeAll(where: { $0.id == id })

        if currentSession?.id == id {
            currentSession = sessions.first
        }
    }

    /// Export session to JSON file
    func exportSession(_ id: UUID) async throws -> URL {
        guard let session = sessions.first(where: { $0.id == id }) else {
            throw SessionError.sessionNotFound
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(session)

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "AutoGPT_Session_\(session.title)_\(Date().timeIntervalSince1970).json"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try data.write(to: fileURL)

        return fileURL
    }

    /// Import session from JSON file
    func importSession(from url: URL) async throws {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var session = try decoder.decode(Session.self, from: data)

        // Generate new ID to avoid conflicts
        session = Session(
            id: UUID(),
            title: session.title + " (Imported)",
            messages: session.messages,
            createdAt: Date(),
            updatedAt: Date(),
            metadata: session.metadata
        )

        sessions.insert(session, at: 0)
        try await saveSession(session)
    }

    /// Load all sessions from persistence
    private func loadAllSessions() async {
        do {
            let keys = try await persistence.listKeys(withPrefix: sessionPrefix)

            var loadedSessions: [Session] = []
            for key in keys {
                if let session: Session = try? await persistence.load(key: key) {
                    loadedSessions.append(session)
                }
            }

            // Sort by updated date (most recent first)
            sessions = loadedSessions.sorted { $0.updatedAt > $1.updatedAt }

            // Set current session to most recent if none exists
            if currentSession == nil {
                currentSession = sessions.first
            }
        } catch {
            print("Failed to load sessions: \(error.localizedDescription)")
            // Create a default session if loading fails
            let defaultSession = createNewSession()
            currentSession = defaultSession
        }
    }

    private func sessionKey(for id: UUID) -> String {
        return "\(sessionPrefix)\(id.uuidString)"
    }

    /// Update current session with new message
    func addMessage(_ message: Message) async {
        guard var session = currentSession else { return }

        session.addMessage(message)
        currentSession = session

        await saveSession(session)
    }

    /// Update session title
    func updateSessionTitle(_ title: String) async {
        guard var session = currentSession else { return }

        session.title = title
        session.updatedAt = Date()
        currentSession = session

        await saveSession(session)
    }
}

// MARK: - Errors

enum SessionError: LocalizedError {
    case sessionNotFound
    case importFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session not found"
        case .importFailed:
            return "Failed to import session"
        case .exportFailed:
            return "Failed to export session"
        }
    }
}
