import Foundation

// MARK: - Envelope

/// Single-file atomic container for all notes-related data.
/// Bump `schemaVersion` when you change the layout and migrate in `loadEnvelope`.
struct NotesEnvelope: Codable {
    var schemaVersion: Int = 1
    var notes: [NoteItem]
    var pageNotes: [Int: String]
    var tags: [String]
    var updatedAt: Date = .init()
}

// MARK: - Protocol

/// Protocol for notes persistence to enable dependency injection and testing
protocol NotesPersistenceProtocol {
    // Existing triplet API (kept for compatibility)
    func saveNotes(_ notes: [NoteItem], for url: URL) throws
    func loadNotes(for url: URL) -> [NoteItem]

    func savePageNotes(_ pageNotes: [Int: String], for url: URL) throws
    func loadPageNotes(for url: URL) -> [Int: String]

    func saveTags(_ tags: Set<String>, for url: URL) throws
    func loadTags(for url: URL) -> Set<String>

    func clearData(for url: URL)
    func validateData(for url: URL) -> Bool

    // NEW: single-file atomic persistence
    func saveEnvelope(_ env: NotesEnvelope, for url: URL) throws
    func loadEnvelope(for url: URL) throws -> NotesEnvelope
    /// Attempts to restore the last backup for the single envelope file.
    @discardableResult
    func restoreBackup(for url: URL) -> Bool
}

// MARK: - Production implementation using EnhancedPersistenceService

@MainActor
final class NotesPersistenceService: NotesPersistenceProtocol {
    private let ps = EnhancedPersistenceService.shared

    // Single-file key
    private let envKey = "DevReader.NotesEnvelope.v1"

    // Legacy keys (kept for migration/validation)
    private let notesKey = "DevReader.Notes.v1"
    private let pageNotesKey = "DevReader.PageNotes.v1"
    private let tagsKey = "DevReader.Tags.v1"

    // MARK: Envelope (preferred)

    func saveEnvelope(_ env: NotesEnvelope, for url: URL) throws {
        try ps.saveCodable(env, forKey: envKey, url: url) // atomic write with backup
    }

    func loadEnvelope(for url: URL) throws -> NotesEnvelope {
        // Preferred: read the envelope
        if let env = ps.loadCodable(NotesEnvelope.self, forKey: envKey, url: url) {
            return env
        }

        // Fallback: stitch legacy files, then persist as envelope for next time
        let legacyNotes = ps.loadCodable([NoteItem].self, forKey: notesKey, url: url) ?? []
        let legacyPageNotes = ps.loadCodable([Int: String].self, forKey: pageNotesKey, url: url) ?? [:]
        let legacyTags = Set(ps.loadCodable([String].self, forKey: tagsKey, url: url) ?? [])

        let env = NotesEnvelope(
            schemaVersion: 1,
            notes: legacyNotes,
            pageNotes: legacyPageNotes,
            tags: Array(legacyTags),
            updatedAt: Date()
        )

        // Best-effort write of migrated format (don’t throw if it fails)
        try? saveEnvelope(env, for: url)
        return env
    }

    @discardableResult
    func restoreBackup(for url: URL) -> Bool {
        ps.restoreBackup(forKey: envKey, url: url)
    }

    // MARK: Compatibility – triplet methods delegate to the envelope

    func saveNotes(_ notes: [NoteItem], for url: URL) throws {
        var env = try loadEnvelope(for: url)
        env.notes = notes
        env.updatedAt = Date()
        try saveEnvelope(env, for: url)
    }

    func loadNotes(for url: URL) -> [NoteItem] {
        (try? loadEnvelope(for: url).notes) ?? []
    }

    func savePageNotes(_ pageNotes: [Int : String], for url: URL) throws {
        var env = try loadEnvelope(for: url)
        env.pageNotes = pageNotes
        env.updatedAt = Date()
        try saveEnvelope(env, for: url)
    }

    func loadPageNotes(for url: URL) -> [Int : String] {
        (try? loadEnvelope(for: url).pageNotes) ?? [:]
    }

    func saveTags(_ tags: Set<String>, for url: URL) throws {
        var env = try loadEnvelope(for: url)
        env.tags = Array(tags)
        env.updatedAt = Date()
        try saveEnvelope(env, for: url)
    }

    func loadTags(for url: URL) -> Set<String> {
        Set((try? loadEnvelope(for: url).tags) ?? [])
    }

    func clearData(for url: URL) {
        // Clears known keys (env + legacy) for the specific PDF
        ps.clearData(for: url)
    }

    func validateData(for url: URL) -> Bool {
        // Prefer the envelope; accept legacy if migrating
        if ps.validateData(forKey: envKey, url: url) { return true }
        let hasLegacy =
            ps.validateData(forKey: notesKey, url: url) ||
            ps.validateData(forKey: pageNotesKey, url: url) ||
            ps.validateData(forKey: tagsKey, url: url)
        return hasLegacy
    }
}

// MARK: - Mock implementation for testing

final class MockNotesPersistenceService: NotesPersistenceProtocol {
    // Store by URL
    var notes: [URL: [NoteItem]] = [:]
    var pageNotes: [URL: [Int: String]] = [:]
    var tags: [URL: Set<String>] = [:]
    var envelopes: [URL: NotesEnvelope] = [:]

    var shouldThrowError = false

    // Triplet
    func saveNotes(_ notes: [NoteItem], for url: URL) throws {
        if shouldThrowError { throw NSError(domain: "MockError", code: 1) }
        self.notes[url] = notes
        // Keep envelope in sync (if present)
        if var env = envelopes[url] {
            env.notes = notes
            env.updatedAt = Date()
            envelopes[url] = env
        }
    }

    func loadNotes(for url: URL) -> [NoteItem] {
        if let env = envelopes[url] { return env.notes }
        return notes[url] ?? []
    }

    func savePageNotes(_ pageNotes: [Int : String], for url: URL) throws {
        if shouldThrowError { throw NSError(domain: "MockError", code: 1) }
        self.pageNotes[url] = pageNotes
        if var env = envelopes[url] {
            env.pageNotes = pageNotes
            env.updatedAt = Date()
            envelopes[url] = env
        }
    }

    func loadPageNotes(for url: URL) -> [Int : String] {
        if let env = envelopes[url] { return env.pageNotes }
        return pageNotes[url] ?? [:]
    }

    func saveTags(_ tags: Set<String>, for url: URL) throws {
        if shouldThrowError { throw NSError(domain: "MockError", code: 1) }
        self.tags[url] = tags
        if var env = envelopes[url] {
            env.tags = Array(tags)
            env.updatedAt = Date()
            envelopes[url] = env
        }
    }

    func loadTags(for url: URL) -> Set<String> {
        if let env = envelopes[url] { return Set(env.tags) }
        return tags[url] ?? []
    }

    func clearData(for url: URL) {
        notes.removeValue(forKey: url)
        pageNotes.removeValue(forKey: url)
        tags.removeValue(forKey: url)
        envelopes.removeValue(forKey: url)
    }

    func validateData(for url: URL) -> Bool {
        return envelopes[url] != nil ||
               notes[url] != nil ||
               pageNotes[url] != nil ||
               tags[url] != nil
    }

    // Envelope
    func saveEnvelope(_ env: NotesEnvelope, for url: URL) throws {
        if shouldThrowError { throw NSError(domain: "MockError", code: 1) }
        envelopes[url] = env
        // Keep triplet mirrors updated for code that still reads them in tests
        notes[url] = env.notes
        pageNotes[url] = env.pageNotes
        tags[url] = Set(env.tags)
    }

    func loadEnvelope(for url: URL) throws -> NotesEnvelope {
        if let env = envelopes[url] {
            return env
        }
        // Stitch from mirrors if present (legacy sim)
        let env = NotesEnvelope(
            schemaVersion: 1,
            notes: notes[url] ?? [],
            pageNotes: pageNotes[url] ?? [:],
            tags: Array(tags[url] ?? []),
            updatedAt: Date()
        )
        envelopes[url] = env
        return env
    }

    @discardableResult
    func restoreBackup(for url: URL) -> Bool {
        // No-op in mock; return false to indicate nothing restored
        return false
    }
}