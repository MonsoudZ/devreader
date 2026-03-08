import Foundation
import os.log

/// Protocol for notes persistence to enable dependency injection and testing.
/// Intentionally NOT @MainActor — implementations must be thread-safe so loads
/// can run off the main thread without blocking the UI.
nonisolated protocol NotesPersistenceProtocol: Sendable {
    func saveNotes(_ notes: [NoteItem], for url: URL) throws
    func loadNotes(for url: URL) -> [NoteItem]

    func savePageNotes(_ pageNotes: [Int: String], for url: URL) throws
    func loadPageNotes(for url: URL) -> [Int: String]

    func saveTags(_ tags: Set<String>, for url: URL) throws
    func loadTags(for url: URL) -> Set<String>

    func clearData(for url: URL)
    func validateData(for url: URL) -> Bool
}

/// Production implementation — calls JSONStorageService directly (thread-safe).
/// Uses content-fingerprint keys with legacy path-hash migration, matching
/// EnhancedPersistenceService's key scheme for data compatibility.
nonisolated final class NotesPersistenceService: NotesPersistenceProtocol, Sendable {
    private let notesKey = "DevReader.Notes.v1"
    private let pageNotesKey = "DevReader.PageNotes.v1"
    private let tagsKey = "DevReader.Tags.v1"

    // MARK: - Key Generation (mirrors EnhancedPersistenceService)

    private func generateKey(_ base: String, for url: URL) -> String {
        let uniqueId = PersistenceService.contentFingerprint(for: url)
            ?? PersistenceService.stableHash(for: url)
        return "\(base).\(uniqueId)"
    }

    private func legacyKey(_ base: String, for url: URL) -> String {
        return "\(base).\(PersistenceService.stableHash(for: url))"
    }

    private func fileURL(forKey finalKey: String) -> URL {
        JSONStorageService.dataDirectory.appendingPathComponent("\(finalKey).json")
    }

    // MARK: - Load with Migration

    /// Tries content-fingerprint key first, falls back to legacy path-hash key.
    /// If found at legacy key, migrates data to new key.
    private func loadWithMigration<T: Codable>(_ type: T.Type, forKey key: String, url: URL) -> T? {
        let finalKey = generateKey(key, for: url)
        if let result = JSONStorageService.loadOptional(type, from: fileURL(forKey: finalKey)) {
            return result
        }

        // Fall back to legacy path-hash key
        let legacy = legacyKey(key, for: url)
        guard legacy != finalKey else { return nil }

        guard let result = JSONStorageService.loadOptional(type, from: fileURL(forKey: legacy)) else { return nil }

        // Migrate: save to new key and delete old
        do {
            try JSONStorageService.save(result, to: fileURL(forKey: finalKey))
            try? FileManager.default.removeItem(at: fileURL(forKey: legacy))
        } catch {
            // Migration failed — data is still at legacy key, not lost
        }

        return result
    }

    // MARK: - Protocol Implementation

    func saveNotes(_ notes: [NoteItem], for url: URL) throws {
        try JSONStorageService.save(notes, to: fileURL(forKey: generateKey(notesKey, for: url)))
    }

    func loadNotes(for url: URL) -> [NoteItem] {
        return loadWithMigration([NoteItem].self, forKey: notesKey, url: url) ?? []
    }

    func savePageNotes(_ pageNotes: [Int: String], for url: URL) throws {
        try JSONStorageService.save(pageNotes, to: fileURL(forKey: generateKey(pageNotesKey, for: url)))
    }

    func loadPageNotes(for url: URL) -> [Int: String] {
        return loadWithMigration([Int: String].self, forKey: pageNotesKey, url: url) ?? [:]
    }

    func saveTags(_ tags: Set<String>, for url: URL) throws {
        try JSONStorageService.save(Array(tags), to: fileURL(forKey: generateKey(tagsKey, for: url)))
    }

    func loadTags(for url: URL) -> Set<String> {
        return Set(loadWithMigration([String].self, forKey: tagsKey, url: url) ?? [])
    }

    func clearData(for url: URL) {
        for key in [notesKey, pageNotesKey, tagsKey] {
            let file = fileURL(forKey: generateKey(key, for: url))
            try? FileManager.default.removeItem(at: file)
            // Also clean up legacy-keyed files
            let legacy = fileURL(forKey: legacyKey(key, for: url))
            try? FileManager.default.removeItem(at: legacy)
        }
    }

    func validateData(for url: URL) -> Bool {
        func check(_ key: String) -> Bool {
            let file = fileURL(forKey: generateKey(key, for: url))
            guard FileManager.default.fileExists(atPath: file.path) else { return false }
            do {
                let data = try Data(contentsOf: file)
                guard !data.isEmpty else { return false }
                _ = try JSONSerialization.jsonObject(with: data)
                return true
            } catch {
                return false
            }
        }
        return check(notesKey) && check(pageNotesKey) && check(tagsKey)
    }
}
