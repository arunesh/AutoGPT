//
//  PersistenceService.swift
//  AutoGPT
//
//  Persistence service for session storage
//

import Foundation

protocol PersistenceService {
    func save<T: Codable>(_ object: T, key: String) async throws
    func load<T: Codable>(key: String) async throws -> T
    func delete(key: String) async throws
    func listKeys(withPrefix prefix: String) async throws -> [String]
}

/// File-based persistence service using JSON
class FilePersistenceService: PersistenceService {
    private let fileManager = FileManager.default
    private let baseDirectory: URL

    init() throws {
        // Get application support directory
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        baseDirectory = appSupport.appendingPathComponent("AutoGPT", isDirectory: true)

        // Create base directory if needed
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.createDirectory(
                at: baseDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    func save<T: Codable>(_ object: T, key: String) async throws {
        let fileURL = baseDirectory.appendingPathComponent("\(key).json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(object)
        try data.write(to: fileURL, options: .atomic)
    }

    func load<T: Codable>(key: String) async throws -> T {
        let fileURL = baseDirectory.appendingPathComponent("\(key).json")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw PersistenceError.notFound
        }

        let data = try Data(contentsOf: fileURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(T.self, from: data)
    }

    func delete(key: String) async throws {
        let fileURL = baseDirectory.appendingPathComponent("\(key).json")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw PersistenceError.notFound
        }

        try fileManager.removeItem(at: fileURL)
    }

    func listKeys(withPrefix prefix: String) async throws -> [String] {
        let contents = try fileManager.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: nil
        )

        return contents
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { $0.hasPrefix(prefix) }
    }
}

/// UserDefaults-based persistence (for simple key-value storage)
class UserDefaultsPersistenceService: PersistenceService {
    private let userDefaults = UserDefaults.standard

    func save<T: Codable>(_ object: T, key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(object)
        userDefaults.set(data, forKey: key)
    }

    func load<T: Codable>(key: String) async throws -> T {
        guard let data = userDefaults.data(forKey: key) else {
            throw PersistenceError.notFound
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(T.self, from: data)
    }

    func delete(key: String) async throws {
        userDefaults.removeObject(forKey: key)
    }

    func listKeys(withPrefix prefix: String) async throws -> [String] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        return Array(allKeys.filter { $0.hasPrefix(prefix) })
    }
}

// MARK: - Errors

enum PersistenceError: LocalizedError {
    case notFound
    case encodingFailed
    case decodingFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Object not found"
        case .encodingFailed:
            return "Failed to encode object"
        case .decodingFailed:
            return "Failed to decode object"
        case .saveFailed:
            return "Failed to save object"
        }
    }
}
