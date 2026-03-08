import Foundation
@testable import DevReader

final class MockNotesPersistenceService: NotesPersistenceProtocol, @unchecked Sendable {
    private let lock = NSLock()

    private var _notes: [URL: [NoteItem]] = [:]
    private var _pageNotes: [URL: [Int: String]] = [:]
    private var _tags: [URL: Set<String>] = [:]
    private var _shouldThrowError = false
    private var _lastSavedNotes: [NoteItem] = []
    private var _lastSavedPageNotes: [Int: String] = [:]
    private var _lastSavedTags: Set<String> = []

    // MARK: - Thread-safe accessors for test assertions

    var notes: [URL: [NoteItem]] {
        get { lock.withLock { _notes } }
        set { lock.withLock { _notes = newValue } }
    }
    var pageNotes: [URL: [Int: String]] {
        get { lock.withLock { _pageNotes } }
        set { lock.withLock { _pageNotes = newValue } }
    }
    var tags: [URL: Set<String>] {
        get { lock.withLock { _tags } }
        set { lock.withLock { _tags = newValue } }
    }
    var shouldThrowError: Bool {
        get { lock.withLock { _shouldThrowError } }
        set { lock.withLock { _shouldThrowError = newValue } }
    }
    var lastSavedNotes: [NoteItem] {
        get { lock.withLock { _lastSavedNotes } }
        set { lock.withLock { _lastSavedNotes = newValue } }
    }
    var lastSavedPageNotes: [Int: String] {
        get { lock.withLock { _lastSavedPageNotes } }
        set { lock.withLock { _lastSavedPageNotes = newValue } }
    }
    var lastSavedTags: Set<String> {
        get { lock.withLock { _lastSavedTags } }
        set { lock.withLock { _lastSavedTags = newValue } }
    }

    // MARK: - Protocol

    func saveNotes(_ notes: [NoteItem], for url: URL) throws {
        try lock.withLock {
            if _shouldThrowError {
                throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
            }
            _notes[url] = notes
            _lastSavedNotes = notes
        }
    }

    func loadNotes(for url: URL) -> [NoteItem] {
        lock.withLock { _notes[url] ?? [] }
    }

    func savePageNotes(_ pageNotes: [Int: String], for url: URL) throws {
        try lock.withLock {
            if _shouldThrowError {
                throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
            }
            _pageNotes[url] = pageNotes
            _lastSavedPageNotes = pageNotes
        }
    }

    func loadPageNotes(for url: URL) -> [Int: String] {
        lock.withLock { _pageNotes[url] ?? [:] }
    }

    func saveTags(_ tags: Set<String>, for url: URL) throws {
        try lock.withLock {
            if _shouldThrowError {
                throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
            }
            _tags[url] = tags
            _lastSavedTags = tags
        }
    }

    func loadTags(for url: URL) -> Set<String> {
        lock.withLock { _tags[url] ?? [] }
    }

    func clearData(for url: URL) {
        lock.withLock {
            _notes.removeValue(forKey: url)
            _pageNotes.removeValue(forKey: url)
            _tags.removeValue(forKey: url)
        }
    }

    func validateData(for url: URL) -> Bool {
        lock.withLock {
            _notes[url] != nil || _pageNotes[url] != nil || _tags[url] != nil
        }
    }
}
